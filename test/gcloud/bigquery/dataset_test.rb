# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "helper"
require "json"
require "uri"

describe Gcloud::Bigquery::Dataset, :mock_bigquery do
  # Create a dataset object with the project's mocked connection object
  let(:dataset_id) { "my_dataset" }
  let(:dataset_name) { "My Dataset" }
  let(:dataset_description) { "This is my dataset" }
  let(:table_id) { "my_table" }
  let(:table_name) { "My Table" }
  let(:table_description) { "This is my table" }
  let(:table_schema) {
    {
      "fields" => [
        {
          "name" => "name",
          "type" => "STRING",
          "mode" => "REQUIRED"
        },
        {
          "name" => "age",
          "type" => "INTEGER"
        },
        {
          "name" => "score",
          "type" => "FLOAT",
          "description" => "A score from 0.0 to 10.0"
        },
        {
          "name" => "active",
          "type" => "BOOLEAN"
        }
      ]
    }
  }
  let(:view_id) { "my_view" }
  let(:view_name) { "My View" }
  let(:view_description) { "This is my view" }
  let(:query) { "SELECT * FROM [table]" }
  let(:default_expiration) { 999 }
  let(:etag) { "etag123456789" }
  let(:location_code) { "US" }
  let(:api_url) { "http://googleapi/bigquery/v2/projects/#{project}/datasets/#{dataset_id}" }
  let(:dataset_hash) { random_dataset_hash dataset_id, dataset_name, dataset_description, default_expiration }
  let(:dataset) { Gcloud::Bigquery::Dataset.from_gapi dataset_hash,
                                                      bigquery.connection }

  it "knows its attributes" do
    dataset.name.must_equal dataset_name
    dataset.description.must_equal dataset_description
    dataset.default_expiration.must_equal default_expiration
    dataset.etag.must_equal etag
    dataset.api_url.must_equal api_url
    dataset.location.must_equal location_code
  end

  it "knows its creation and modification times" do
    now = Time.now

    dataset.gapi["creationTime"] = (now.to_f * 1000).floor
    dataset.created_at.must_be_close_to now

    dataset.gapi["lastModifiedTime"] = (now.to_f * 1000).floor
    dataset.modified_at.must_be_close_to now
  end

  it "can delete itself" do
    mock_connection.delete "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}" do |env|
      env.params.wont_include "deleteContents"
      [200, {"Content-Type" => "application/json"}, ""]
    end

    dataset.delete
  end

  it "can delete itself and all table data" do
    mock_connection.delete "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}" do |env|
      env.params.must_include "deleteContents"
      env.params["deleteContents"].must_equal "true"
      [200, {"Content-Type" => "application/json"}, ""]
    end

    dataset.delete force: true
  end

  it "creates an empty table" do
    mock_connection.post "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      [200, {"Content-Type" => "application/json"},
       create_table_json(table_id)]
    end

    table = dataset.create_table table_id
    table.must_be_kind_of Gcloud::Bigquery::Table
    table.table_id.must_equal table_id
    table.must_be :table?
    table.wont_be :view?
  end

  it "creates a table with a name, description, and schema option" do
    mock_connection.post "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      JSON.parse(env.body)["friendlyName"].must_equal table_name
      JSON.parse(env.body)["description"].must_equal table_description
      JSON.parse(env.body)["schema"].must_equal table_schema
      [200, {"Content-Type" => "application/json"},
       create_table_json(table_id, table_name, table_description)]
    end

    table = dataset.create_table table_id,
                                 name: table_name,
                                 description: table_description,
                                 schema: table_schema
    table.must_be_kind_of Gcloud::Bigquery::Table
    table.table_id.must_equal table_id
    table.name.must_equal table_name
    table.description.must_equal table_description
    table.schema.must_equal table_schema
    table.must_be :table?
    table.wont_be :view?
  end

  it "creates a table with a schema block" do
    mock_connection.post "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      JSON.parse(env.body)["schema"].must_equal table_schema
      [200, {"Content-Type" => "application/json"},
       create_table_json(table_id, table_name, table_description)]
    end

    table = dataset.create_table table_id do |schema|
      schema.string "name", mode: :required
      schema.integer "age"
      schema.float "score", description: "A score from 0.0 to 10.0"
      schema.boolean "active"
    end
    table.must_be_kind_of Gcloud::Bigquery::Table
    table.table_id.must_equal table_id
    table.schema.must_equal table_schema
    table.must_be :table?
    table.wont_be :view?
  end

  it "can create a empty view" do
    mock_connection.post "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      [200, {"Content-Type" => "application/json"},
       create_view_json(view_id, query)]
    end

    table = dataset.create_view view_id, query
    table.table_id.must_equal view_id
    table.query.must_equal query
    table.must_be_kind_of Gcloud::Bigquery::View
    table.must_be :view?
    table.wont_be :table?
  end

  it "can create a view with a name and description" do
    mock_connection.post "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      JSON.parse(env.body)["friendlyName"].must_equal view_name
      JSON.parse(env.body)["description"].must_equal view_description
      [200, {"Content-Type" => "application/json"},
       create_view_json(view_id, query, view_name, view_description)]
    end

    table = dataset.create_view view_id, query,
                                name: view_name,
                                description: view_description
    table.must_be_kind_of Gcloud::Bigquery::View
    table.table_id.must_equal view_id
    table.query.must_equal query
    table.name.must_equal view_name
    table.description.must_equal view_description
    table.must_be :view?
    table.wont_be :table?
  end

  it "lists tables" do
    num_tables = 3
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      [200, {"Content-Type" => "application/json"},
       list_tables_json(num_tables)]
    end

    tables = dataset.tables
    tables.size.must_equal num_tables
    tables.each { |ds| ds.must_be_kind_of Gcloud::Bigquery::Table }
  end

  it "paginates tables" do
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      env.params.wont_include "pageToken"
      [200, {"Content-Type" => "application/json"},
       list_tables_json(3, "next_page_token", 5)]
    end
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      env.params.must_include "pageToken"
      env.params["pageToken"].must_equal "next_page_token"
      [200, {"Content-Type" => "application/json"},
       list_tables_json(2, nil, 5)]
    end

    first_tables = dataset.tables
    first_tables.count.must_equal 3
    first_tables.each { |ds| ds.must_be_kind_of Gcloud::Bigquery::Table }
    first_tables.token.wont_be :nil?
    first_tables.token.must_equal "next_page_token"
    first_tables.total.must_equal 5

    second_tables = dataset.tables token: first_tables.token
    second_tables.count.must_equal 2
    second_tables.each { |ds| ds.must_be_kind_of Gcloud::Bigquery::Table }
    second_tables.token.must_be :nil?
    second_tables.total.must_equal 5
  end

  it "paginates tables with max set" do
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      env.params.must_include "maxResults"
      env.params["maxResults"].must_equal "3"
      [200, {"Content-Type" => "application/json"},
       list_tables_json(3, "next_page_token")]
    end

    tables = dataset.tables max: 3
    tables.count.must_equal 3
    tables.each { |ds| ds.must_be_kind_of Gcloud::Bigquery::Table }
    tables.token.wont_be :nil?
    tables.token.must_equal "next_page_token"
  end

  it "paginates tables without max set" do
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables" do |env|
      env.params.wont_include "maxResults"
      [200, {"Content-Type" => "application/json"},
       list_tables_json(3, "next_page_token")]
    end

    tables = dataset.tables
    tables.count.must_equal 3
    tables.each { |ds| ds.must_be_kind_of Gcloud::Bigquery::Table }
    tables.token.wont_be :nil?
    tables.token.must_equal "next_page_token"
  end

  it "finds a table" do
    found_table_id = "found_table"

    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}/tables/#{found_table_id}" do |env|
      [200, {"Content-Type" => "application/json"},
       find_table_json(found_table_id)]
    end

    table = dataset.table found_table_id
    table.must_be_kind_of Gcloud::Bigquery::Table
    table.table_id.must_equal found_table_id
  end

  def create_table_json id, name = nil, description = nil
    random_table_hash(dataset_id, id, name, description).to_json
  end

  def create_view_json id, query, name = nil, description = nil
    hash = random_table_hash dataset_id, id, name, description
    hash["view"] = {"query" => query}
    hash["type"] = "VIEW"
    hash.to_json
  end

  def find_table_json id, name = nil, description = nil
    random_table_hash(dataset_id, id, name, description).to_json
  end

  def list_tables_json count = 2, token = nil, total = nil
    tables = count.times.map { random_table_small_hash(dataset_id) }
    hash = {"kind" => "bigquery#tableList", "tables" => tables,
            "totalItems" => (total || count)}
    hash["nextPageToken"] = token unless token.nil?
    hash.to_json
  end
end
