# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'slop'
require_relative 'lib/git_lab_indexer'

# index(options) -> count
#
# Indexes documents that have been modified within a time window.
#
# @param [Hash] options The options for the indexing.
# @option options [String] :gitlab_host The base URL of the GitLab server.
# @option options [String] :gitlab_token The authentication token to communicate with the GitLab server.
# @option options [String] :host The base URL of the WorkplaceSearch server.
# @option options [String] :access_token The authentication token to communicate with the Workplace Search server.
# @option options [String] :content_source_id The ID of the content source into which documents will be indexed.
# @option options [String] :from The ISO-8601 date time from which documents should be indexed.
# @option options [String] :to The ISO-8601 date time to which documents should be indexed.
def index(options)
  indexer = GitLabIndexer.new(
    gitlab_host: options[:gitlab_host],
    gitlab_token: options[:gitlab_token],
    workplace_search_host: options[:host],
    workplace_search_access_token: options[:access_token],
    content_source_id: options[:content_source_id]
  )

  indexer.index(
    from: Time.iso8601(options[:from]),
    to: Time.iso8601(options[:to])
  )
end

def parse_options
  Slop.parse do |o|
    o.string '-h', '--host', 'The Workplace Search host', required: true
    o.string '-a', '--access-token', 'The access token for the content source to authenticate with Workplace Search', required: true
    o.string '-c', '--content-source-id', 'The id of the content source to index into', required: true
    o.string '--gitlab-host', 'The GitLab host that data will be pulled from', required: true
    o.string '--gitlab-token', 'The token used to authenticate with GitLab', required: true
    o.string '-f', '--from', 'The ISO-8601 timestamp to index data from', required: true
    o.string '-t', '--to', 'The ISO-8601 timestamp to index data to', required: true
  end
end

if $0 == __FILE__
  num_indexed = index(parse_options)
  puts "Indexed #{num_indexed} documents"
end