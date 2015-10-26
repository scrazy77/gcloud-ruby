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

describe Gcloud::Bigquery::Dataset, :attributes, :mock_bigquery do
  # Create a dataset object with the project's mocked connection object
  let(:dataset_id) { "my_dataset" }
  let(:dataset_name) { "My Dataset" }
  let(:description) { "This is my dataset" }
  let(:default_expiration) { 999 }
  let(:dataset_hash) { random_dataset_small_hash dataset_id, dataset_name }
  let(:dataset_full_json) { random_dataset_hash(dataset_id, dataset_name, description, default_expiration).to_json }
  let(:dataset) { Gcloud::Bigquery::Dataset.from_gapi dataset_hash,
                                                      bigquery.connection }

  it "gets full data for created_at" do
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}" do |env|
      [200, {"Content-Type"=>"application/json"},
       dataset_full_json]
    end

    dataset.created_at.must_be_close_to Time.now, 10

    # A second call to attribute does not make a second HTTP API call
    dataset.created_at.must_be_close_to Time.now, 10
  end

  it "gets full data for modified_at" do
    mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}" do |env|
      [200, {"Content-Type"=>"application/json"},
       dataset_full_json]
    end

    dataset.modified_at.must_be_close_to Time.now, 10

    # A second call to attribute does not make a second HTTP API call
    dataset.modified_at.must_be_close_to Time.now, 10
  end

  def self.attr_test attr, val
    define_method "test_#{attr}" do
      mock_connection.get "/bigquery/v2/projects/#{project}/datasets/#{dataset.dataset_id}" do |env|
        [200, {"Content-Type"=>"application/json"},
         dataset_full_json]
      end

      dataset.send(attr).must_equal val

      # A second call to attribute does not make a second HTTP API call
      dataset.send(attr).must_equal val
    end
  end

  attr_test :description, "This is my dataset"
  attr_test :default_expiration, 999
  attr_test :etag, "etag123456789"
  attr_test :api_url, "http://googleapi/bigquery/v2/projects/test-project/datasets/my_dataset"
  attr_test :location, "US"

end
