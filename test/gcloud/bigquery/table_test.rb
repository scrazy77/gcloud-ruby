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

describe Gcloud::Bigquery::Table, :mock_bigquery do
  # Create a table object with the project's mocked connection object
  let(:dataset) { "my_dataset" }
  let(:table_id) { "my_table" }
  let(:table_name) { "My Table" }
  let(:description) { "This is my table" }
  let(:etag) { "etag123456789" }
  let(:location_code) { "US" }
  let(:api_url) { "http://googleapi/bigquery/v2/projects/#{project}/datasets/#{dataset}/tables/#{table_id}" }
  let(:table_hash) { random_table_hash dataset, table_id, table_name, description }
  let(:table) { Gcloud::Bigquery::Table.from_gapi table_hash,
                                                  bigquery.connection }

  it "knows its attributes" do
    table.name.must_equal table_name
    table.description.must_equal description
    table.etag.must_equal etag
    table.api_url.must_equal api_url
    table.bytes_count.must_equal 1000
    table.rows_count.must_equal 100
    table.table?.must_equal true
    table.view?.must_equal false
    table.location.must_equal location_code
  end

  it "knows its fully-qualified ID" do
    table.id.must_equal "#{project}:#{dataset}.#{table_id}"
  end

  it "knows its fully-qualified query ID" do
    table.query_id.must_equal "[#{project}:#{dataset}.#{table_id}]"
  end

  it "knows its creation and modification and expiration times" do
    now = Time.now

    table.gapi["creationTime"] = (now.to_f * 1000).floor
    table.created_at.must_be_close_to now

    table.gapi["lastModifiedTime"] = (now.to_f * 1000).floor
    table.modified_at.must_be_close_to now

    table.gapi["expirationTime"] = nil
    table.expires_at.must_be :nil?

    table.gapi["expirationTime"] = (now.to_f * 1000).floor
    table.expires_at.must_be_close_to now
  end

  it "knows schema, fields, and headers" do
    table.schema.must_be_kind_of Hash
    table.schema.keys.must_include "fields"
    table.fields.must_equal table.schema["fields"]
    table.headers.must_equal ["name", "age", "score", "active"]
  end

  it "can delete itself" do
    mock_connection.delete "/bigquery/v2/projects/#{project}/datasets/#{table.dataset_id}/tables/#{table.table_id}" do |env|
      [200, {"Content-Type"=>"application/json"}, ""]
    end

    table.delete
  end

  it "can reload itself" do
    new_description = "New description of the table."
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{table.dataset_id}/tables/#{table.table_id}" do |env|
      [200, {"Content-Type"=>"application/json"},
       random_table_hash(dataset, table_id, table_name, new_description).to_json]
    end

    table.description.must_equal description
    table.reload!
    table.description.must_equal new_description
  end
end
