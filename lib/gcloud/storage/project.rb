#--
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

require "gcloud/gce"
require "gcloud/storage/errors"
require "gcloud/storage/connection"
require "gcloud/storage/credentials"
require "gcloud/storage/bucket"
require "gcloud/storage/bucket/cors"
require "gcloud/storage/file"

module Gcloud
  module Storage
    ##
    # = Project
    #
    # Represents the project that storage buckets and files belong to.
    # All data in Google Cloud Storage belongs inside a project.
    # A project consists of a set of users, a set of APIs, billing,
    # authentication, and monitoring settings for those APIs.
    #
    # Gcloud::Storage::Project is the main object for interacting with
    # Google Storage. Gcloud::Storage::Bucket objects are created,
    # read, updated, and deleted by Gcloud::Storage::Project.
    #
    #   require "gcloud"
    #
    #   gcloud = Gcloud.new
    #   storage = gcloud.storage
    #
    #   bucket = storage.bucket "my-bucket"
    #   file = bucket.file "path/to/my-file.ext"
    #
    # See Gcloud#storage
    class Project
      ##
      # The Connection object.
      attr_accessor :connection #:nodoc:

      ##
      # Creates a new Project instance.
      #
      # See Gcloud#storage
      def initialize project, credentials #:nodoc:
        project = project.to_s # Always cast to a string
        fail ArgumentError, "project is missing" if project.empty?
        @connection = Connection.new project, credentials
      end

      ##
      # The Storage project connected to.
      #
      # === Example
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new "my-todo-project",
      #                       "/path/to/keyfile.json"
      #   storage = gcloud.storage
      #
      #   storage.project #=> "my-todo-project"
      #
      def project
        connection.project
      end

      ##
      # Default project.
      def self.default_project #:nodoc:
        ENV["STORAGE_PROJECT"] ||
          ENV["GCLOUD_PROJECT"] ||
          ENV["GOOGLE_CLOUD_PROJECT"] ||
          Gcloud::GCE.project_id
      end

      ##
      # Retrieves a list of buckets for the given project.
      #
      # === Parameters
      #
      # +options+::
      #   An optional Hash for controlling additional behavior. (+Hash+)
      # <code>options[:prefix]</code>::
      #   Filter results to buckets whose names begin with this prefix.
      #   (+String+)
      # <code>options[:token]</code>::
      #   A previously-returned page token representing part of the larger set
      #   of results to view. (+String+)
      # <code>options[:max]</code>::
      #   Maximum number of buckets to return. (+Integer+)
      #
      # === Returns
      #
      # Array of Gcloud::Storage::Bucket (Gcloud::Storage::Bucket::List)
      #
      # === Examples
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   buckets = storage.buckets
      #   buckets.each do |bucket|
      #     puts bucket.name
      #   end
      #
      # You can also retrieve all buckets whose names begin with a prefix using
      # the +:prefix+ option:
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   user_buckets = storage.buckets prefix: "user-"
      #
      # If you have a significant number of buckets, you may need to paginate
      # through them: (See Bucket::List#token)
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   all_buckets = []
      #   tmp_buckets = storage.buckets
      #   while tmp_buckets.any? do
      #     tmp_buckets.each do |bucket|
      #       all_buckets << bucket
      #     end
      #     # break loop if no more buckets available
      #     break if tmp_buckets.token.nil?
      #     # get the next group of buckets
      #     tmp_buckets = storage.buckets token: tmp_buckets.token
      #   end
      #
      def buckets options = {}
        resp = connection.list_buckets options
        if resp.success?
          Bucket::List.from_response resp, connection
        else
          fail ApiError.from_response(resp)
        end
      end
      alias_method :find_buckets, :buckets

      ##
      # Retrieves bucket by name.
      #
      # === Parameters
      #
      # +bucket_name+::
      #   Name of a bucket. (+String+)
      #
      # === Returns
      #
      # Gcloud::Storage::Bucket or nil if bucket does not exist
      #
      # === Example
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   bucket = storage.bucket "my-bucket"
      #   puts bucket.name
      #
      def bucket bucket_name
        resp = connection.get_bucket bucket_name
        if resp.success?
          Bucket.from_gapi resp.data, connection
        else
          return nil if resp.data["error"]["code"] == 404
          fail ApiError.from_response(resp)
        end
      end
      alias_method :find_bucket, :bucket

      ##
      # Creates a new bucket with optional attributes. Also accepts a block for
      # defining the CORS configuration for a static website served from the
      # bucket. See Bucket::Cors for details. For more information about
      # configuring buckets as static websites, see {How to Host a Static
      # Website }[https://cloud.google.com/storage/docs/website-configuration].
      # For more information about CORS, see {Cross-Origin Resource Sharing
      # (CORS)}[https://cloud.google.com/storage/docs/cross-origin].
      #
      # === Parameters
      #
      # +bucket_name+::
      #   Name of a bucket. (+String+)
      # +options+::
      #   An optional Hash for controlling additional behavior. (+Hash+)
      # <code>options[:cors]</code>::
      #   The CORS rules for the bucket. Accepts an array of hashes containing
      #   the attributes specified for the {resource description of
      #   cors}[https://cloud.google.com/storage/docs/json_api/v1/buckets#cors].
      # <code>options[:location]</code>::
      #   The location of the bucket. Object data for objects in the bucket
      #   resides in physical storage within this region. Possible values
      #   include +ASIA+, +EU+, and +US+.(See the {developer's
      #   guide}[https://cloud.google.com/storage/docs/bucket-locations] for the
      #   authoritative list. The default value is +US+. (+String+)
      # <code>options[:logging_bucket]</code>::
      #   The destination bucket for the bucket's logs. For more information,
      #   see {Access
      #   Logs}[https://cloud.google.com/storage/docs/access-logs]. (+String+)
      # <code>options[:logging_prefix]</code>::
      #   The prefix used to create log object names for the bucket. It can be
      #   at most 900 characters and must be a {valid object
      #   name}[https://cloud.google.com/storage/docs/bucket-naming#objectnames]
      #   . By default, the object prefix is the name
      #   of the bucket for which the logs are enabled. For more information,
      #   see {Access Logs}[https://cloud.google.com/storage/docs/access-logs].
      #   (+String+)
      # <code>options[:retries]</code>::
      #   The number of times the API call should be retried.
      #   Default is Gcloud::Backoff.retries. (+Integer+)
      # <code>options[:storage_class]</code>::
      #   Defines how objects in the bucket are stored and determines the SLA
      #   and the cost of storage. Values include +:standard+, +:nearline+, and
      #   +:dra+ (Durable Reduced Availability), as well as the strings returned
      #   by Bucket#storage_class. For more information, see {Storage
      #   Classes}[https://cloud.google.com/storage/docs/storage-classes].
      #   The default value is +:standard+. (+Symbol+ or +String+)
      # <code>options[:versioning]</code>::
      #   Whether {Object
      #   Versioning}[https://cloud.google.com/storage/docs/object-versioning]
      #   is to be enabled for the bucket. The default value is +false+.
      #   (+Boolean+)
      # <code>options[:website_main]</code>::
      #   The index page returned from a static website served from the bucket
      #   when a site visitor requests the top level directory. For more
      #   information, see {How to Host a Static Website
      #   }[https://cloud.google.com/storage/docs/website-configuration#step4].
      # <code>options[:website_404]</code>::
      #   The page returned from a static website served from the bucket when a
      #   site visitor requests a resource that does not exist. For more
      #   information, see {How to Host a Static Website
      #   }[https://cloud.google.com/storage/docs/website-configuration#step4].
      #
      # === Returns
      #
      # Gcloud::Storage::Bucket
      #
      # === Examples
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   bucket = storage.create_bucket "my-bucket"
      #
      # The API call to create the bucket may be retried under certain
      # conditions. See Gcloud::Backoff to control this behavior, or
      # specify the wanted behavior in the call with the +:retries:+ option:
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   bucket = storage.create_bucket "my-bucket", retries: 5
      #
      # You can pass {website
      # settings}[https://cloud.google.com/storage/docs/website-configuration]
      # for the bucket, including a block that defines CORS rule. See
      # Bucket::Cors for details.
      #
      #   require "gcloud"
      #
      #   gcloud = Gcloud.new
      #   storage = gcloud.storage
      #
      #   options = {
      #     website_main: "index.html"
      #     website_404: "not_found.html"
      #   }
      #   bucket = storage.create_bucket "my-bucket", options do |c|
      #     c.add_rule ["http://example.org", "https://example.org"],
      #                "*",
      #                response_headers: ["X-My-Custom-Header"],
      #                max_age: 300
      #   end
      #
      def create_bucket bucket_name, options = {}
        options[:acl] = acl_rule options[:acl]
        options[:default_acl] = acl_rule options[:default_acl]
        if block_given?
          cors_builder = Bucket::Cors.new
          yield cors_builder
          options[:cors] = cors_builder if cors_builder.changed?
        end
        insert_bucket bucket_name, options
      end

      protected

      def acl_rule option_name
        Bucket::Acl.predefined_rule_for option_name
      end

      def insert_bucket bucket_name, options
        resp = connection.insert_bucket bucket_name, options
        if resp.success?
          Bucket.from_gapi resp.data, connection
        else
          fail ApiError.from_response(resp)
        end
      end
    end
  end
end
