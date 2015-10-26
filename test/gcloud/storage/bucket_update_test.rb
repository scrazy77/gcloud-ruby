# Copyright 2014 Google Inc. All rights reserved.
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

describe Gcloud::Storage::Bucket, :update, :mock_storage do
  # Create a bucket object with the project's mocked connection object
  let(:bucket_name) { "new-bucket-#{Time.now.to_i}" }
  let(:bucket_url_root) { "https://www.googleapis.com/storage/v1" }
  let(:bucket_url) { "#{bucket_url_root}/b/#{bucket_name}" }
  let(:bucket_location) { "US" }
  let(:bucket_storage_class) { "STANDARD" }
  let(:bucket_logging_bucket) { "bucket-name-logging" }
  let(:bucket_logging_prefix) { "AccessLog" }
  let(:bucket_website_main) { "index.html" }
  let(:bucket_website_404) { "404.html" }
  let(:bucket_cors) { [{ "maxAgeSeconds" => 300,
                  "origin" => ["http://example.org", "https://example.org"],
                  "method" => ["*"],
                  "responseHeader" => ["X-My-Custom-Header"] }] }

  let(:bucket_hash) { random_bucket_hash bucket_name, bucket_url_root, bucket_location, bucket_storage_class }
  let(:bucket) { Gcloud::Storage::Bucket.from_gapi bucket_hash, storage.connection }

  let(:bucket_with_cors_hash) { random_bucket_hash bucket_name, bucket_url_root, bucket_location, bucket_storage_class,
                                                   nil, nil, nil, nil, nil, bucket_cors }
  let(:bucket_with_cors) { Gcloud::Storage::Bucket.from_gapi bucket_with_cors_hash, storage.connection }

  it "updates its versioning" do
    mock_connection.patch "/storage/v1/b/#{bucket_name}" do |env|
      JSON.parse(env.body)["versioning"]["enabled"].must_equal true
      [200, {"Content-Type"=>"application/json"},
       random_bucket_hash(bucket_name, bucket_url, bucket_location, bucket_storage_class, true).to_json]
    end

    bucket.versioning?.must_equal false
    bucket.versioning = true
    bucket.versioning?.must_equal true
  end

  it "updates its logging bucket" do
    mock_connection.patch "/storage/v1/b/#{bucket_name}" do |env|
      JSON.parse(env.body)["logging"]["logBucket"].must_equal bucket_logging_bucket
      [200, {"Content-Type"=>"application/json"},
       random_bucket_hash(bucket_name, bucket_url, bucket_location, bucket_storage_class, nil, bucket_logging_bucket).to_json]
    end

    bucket.logging_bucket.must_equal nil
    bucket.logging_bucket = bucket_logging_bucket
    bucket.logging_bucket.must_equal bucket_logging_bucket
  end

  it "updates its website main page" do
    mock_connection.patch "/storage/v1/b/#{bucket_name}" do |env|
      JSON.parse(env.body)["website"]["mainPageSuffix"].must_equal bucket_website_main
      [200, {"Content-Type"=>"application/json"},
       random_bucket_hash(bucket_name, bucket_url, bucket_location, bucket_storage_class, nil, nil, nil, bucket_website_main).to_json]
    end

    bucket.website_main.must_equal nil
    bucket.website_main = bucket_website_main
    bucket.website_main.must_equal bucket_website_main
  end

  it "updates its website not found 404 page" do
    mock_connection.patch "/storage/v1/b/#{bucket_name}" do |env|
      JSON.parse(env.body)["website"]["notFoundPage"].must_equal bucket_website_404
      [200, {"Content-Type"=>"application/json"},
       random_bucket_hash(bucket_name, bucket_url, bucket_location,
                          bucket_storage_class, nil, nil, nil, nil,
                          bucket_website_404).to_json]
    end

    bucket.website_404.must_equal nil
    bucket.website_404 = bucket_website_404
    bucket.website_404.must_equal bucket_website_404
  end

  it "sets the cors rules" do
    mock_connection.patch "/storage/v1/b/#{bucket.name}" do |env|
      json = JSON.parse env.body
      rules = json["cors"]
      rules.wont_be :nil?
      rules.must_be_kind_of Array
      rules.wont_be :empty?
      rules.count.must_equal 1
      rule = rules.first
      rule.wont_be :nil?
      rule.must_be_kind_of Hash
      rule["maxAgeSeconds"].must_equal 300
      rule["origin"].must_equal ["http://example.org", "https://example.org"]
      rule["method"].must_equal ["*"]
      rule["responseHeader"].must_equal ["X-My-Custom-Header"]

      updated_gapi = bucket.gapi.dup
      updated_gapi["cors"] = json["cors"]
      [200, { "Content-Type" => "application/json" },
       random_bucket_hash(bucket_name, bucket_url, bucket_location,
                                 bucket_storage_class, nil, nil, nil, nil, nil,
                                 bucket_cors).to_json]
    end

    bucket.cors.must_equal []
    bucket.cors = bucket_cors
    bucket.cors.must_equal bucket_cors
  end

  it "updates multiple attributes in a block" do
    mock_connection.patch "/storage/v1/b/#{bucket_name}" do |env|
      JSON.parse(env.body)["website"]["mainPageSuffix"].must_equal bucket_website_main
      [200, {"Content-Type"=>"application/json"},
       random_bucket_hash(bucket_name, bucket_url, bucket_location, bucket_storage_class, nil, nil, nil, bucket_website_main, bucket_website_404).to_json]
    end

    bucket.website_main.must_equal nil
    bucket.website_404.must_equal nil
    bucket.update do |b|
      b.website_main = bucket_website_main
      b.website_404 = bucket_website_404
    end
    bucket.website_main.must_equal bucket_website_main
    bucket.website_404.must_equal bucket_website_404
  end

  it "updates raw CORS rules in a block" do
    mock_connection.patch "/storage/v1/b/#{bucket_with_cors.name}" do |env|
      json = JSON.parse env.body
      rules = json["cors"]
      rules.count.must_equal 1
      rule = rules.first
      rule["maxAgeSeconds"].must_equal 600
      rule["origin"].must_equal ["http://example.org", "https://example.org", "https://example.com"]
      rule["method"].must_equal ["PUT"]
      rule["responseHeader"].must_equal ["X-My-Custom-Header", "X-Another-Custom-Header"]

      updated_gapi = bucket_with_cors.gapi.dup
      updated_gapi["cors"] = json["cors"]
      [200, { "Content-Type" => "application/json" },
       random_bucket_hash(bucket_name, bucket_url, bucket_location,
                                 bucket_storage_class, nil, nil, nil, nil, nil,
                                 bucket_cors).to_json]
    end


    bucket_with_cors.update do |b|
      b.cors.first["maxAgeSeconds"] = 600
      b.cors.first["origin"] << "https://example.com"
      b.cors.first["method"] = ["PUT"]
      b.cors.first["responseHeader"] << "X-Another-Custom-Header"
    end
  end

  it "adds CORS rules in a nested block in update" do
      mock_connection.patch "/storage/v1/b/#{bucket.name}" do |env|
        json = JSON.parse env.body
        rules = json["cors"]
        rules.count.must_equal 3
        rules[0]["maxAgeSeconds"].must_equal 1800
        rules[0]["origin"].must_equal ["http://example.org"]
        rules[0]["method"].must_equal ["GET"]
        rules[0]["responseHeader"].must_equal []
        rules[1]["maxAgeSeconds"].must_equal 300
        rules[1]["origin"].must_equal ["http://example.org", "https://example.org"]
        rules[1]["method"].must_equal ["PUT", "DELETE"]
        rules[1]["responseHeader"].must_equal ["X-My-Custom-Header"]
        rules[2]["maxAgeSeconds"].must_equal 1800
        rules[2]["origin"].must_equal ["http://example.com"]
        rules[2]["method"].must_equal ["*"]
        rules[2]["responseHeader"].must_equal ["X-Another-Custom-Header"]

        updated_gapi = bucket.gapi.dup
        updated_gapi["cors"] = json["cors"]
        [200, { "Content-Type" => "application/json" },
         random_bucket_hash(bucket_name, bucket_url, bucket_location,
                                   bucket_storage_class, nil, nil, nil, nil, nil,
                                   bucket_cors).to_json]
      end


      bucket.update do |b|
        b.cors do |c|
          c.add_rule "http://example.org", "GET"
          c.add_rule ["http://example.org", "https://example.org"],
                     ["PUT", "DELETE"],
                     headers: ["X-My-Custom-Header"],
                     max_age: 300
          c.add_rule "http://example.com",
                     "*",
                     headers: "X-Another-Custom-Header"
        end
      end
    end

  it "adds CORS rules in a block to cors" do
      mock_connection.patch "/storage/v1/b/#{bucket.name}" do |env|
        json = JSON.parse env.body
        rules = json["cors"]
        rules.count.must_equal 3
        rules[0]["maxAgeSeconds"].must_equal 1800
        rules[0]["origin"].must_equal ["http://example.org"]
        rules[0]["method"].must_equal ["GET"]
        rules[0]["responseHeader"].must_equal []
        rules[1]["maxAgeSeconds"].must_equal 300
        rules[1]["origin"].must_equal ["http://example.org", "https://example.org"]
        rules[1]["method"].must_equal ["PUT", "DELETE"]
        rules[1]["responseHeader"].must_equal ["X-My-Custom-Header"]
        rules[2]["maxAgeSeconds"].must_equal 1800
        rules[2]["origin"].must_equal ["http://example.com"]
        rules[2]["method"].must_equal ["*"]
        rules[2]["responseHeader"].must_equal ["X-Another-Custom-Header"]

        updated_gapi = bucket.gapi.dup
        updated_gapi["cors"] = json["cors"]
        [200, { "Content-Type" => "application/json" },
         random_bucket_hash(bucket_name, bucket_url, bucket_location,
                                   bucket_storage_class, nil, nil, nil, nil, nil,
                                   bucket_cors).to_json]
      end


      returned_cors = bucket.cors do |c|
        c.add_rule "http://example.org", "GET"
        c.add_rule ["http://example.org", "https://example.org"],
                   ["PUT", "DELETE"],
                   headers: ["X-My-Custom-Header"],
                   max_age: 300
        c.add_rule "http://example.com",
                   "*",
                   headers: "X-Another-Custom-Header"
      end
      returned_cors.frozen?.must_equal true
      returned_cors.first.frozen?.must_equal true
    end

  it "updates CORS rules in a block to cors" do
      mock_connection.patch "/storage/v1/b/#{bucket_with_cors.name}" do |env|
        json = JSON.parse env.body
        rules = json["cors"]
        rules.count.must_equal 1
        rules[0]["maxAgeSeconds"].must_equal 1800
        rules[0]["origin"].must_equal ["http://example.net"]
        rules[0]["method"].must_equal ["GET"]
        rules[0]["responseHeader"].must_equal []

        updated_gapi = bucket_with_cors.gapi.dup
        updated_gapi["cors"] = json["cors"]
        [200, { "Content-Type" => "application/json" },
         random_bucket_hash(bucket_name, bucket_url, bucket_location,
                                   bucket_storage_class, nil, nil, nil, nil, nil,
                                   bucket_cors).to_json]
      end

      bucket_with_cors.cors.size.must_equal 1
      bucket_with_cors.cors[0]["origin"].must_equal ["http://example.org", "https://example.org"]
      bucket_with_cors.cors do |c|
        c.add_rule "http://example.net", "GET"
        c.add_rule "http://example.net", "POST"
        # Remove the last CORS rule from the array
        c.pop
        # Remove all existing rules with the https protocol
        c.delete_if { |r| r["origin"].include? "http://example.org" }
      end
    end
end
