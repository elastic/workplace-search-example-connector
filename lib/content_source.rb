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

require 'http'

class ContentSource

  attr_reader :id

  def initialize(id:)
    @id = id
  end

  # create(host:, username:, password:, name:) -> ContentSource
  #
  # Creates a new ContentSource in WorkplaceSearch with a schema suitable for GitLab.
  #
  # @param [String] host The base URL of WorkplaceSearch.
  # @param [String] username The username for the user that will create the ContentSource.
  # @param [String] password The password of the user.
  # @param [String] name The name of the ContentSource.
  # @return [ContentSource] The ContentSource that can be used for indexing operations.
  def self.create(host:, username:, password:, name:)
    response = HTTP.basic_auth(:user => username, :pass => password)
      .post(
        "#{host}/api/ws/v1/sources",
        json: {
          name: name,
          schema: {
            name: 'text',
            description: 'text',
            created_at: 'date',
            last_activity_at: 'date',
            url: 'text',
            content: 'text',
            project_id: 'text',
            gitlab_id: 'text'
          },
          display: {
            title_field: 'name',
            description_field: 'description',
            url_field: 'url',
            detail_fields: [
              { field_name: 'description', label: 'Description' },
              { field_name: 'content', label: 'Content' },
              { field_name: 'created_at', label: 'Created At' },
              { field_name: 'last_activity_at', label: 'Updated At' },
            ]
          }
        }
      )

    raise "Failed to create ContentSource because #{response.status}: #{response.body}" unless response.status.ok?

    json = JSON.parse(response.body)
    ContentSource.new(id: json['id'])
  end

  # deindex(client:, ids:) -> Number
  #
  # Deletes the documents with the given IDs from WorkplaceSearch.
  #
  # @param [WorkplaceSearchClient] client The client for calling WorkplaceSearch.
  # @param [Array<String>] ids The ids of the documents to delete
  # @return [Number] The number of documents deleted.
  def deindex(client:, ids:)
    ids.each_slice(batch_size).each do |next_batch|
      response = client.post("/api/ws/v1/sources/#{id}/documents/bulk_destroy", next_batch)

      raise "Failed to delete batch of #{ids.size} documents because #{response.status}: #{response.body}" unless response.status.ok?
    end

    ids.size
  end

  # documents_modified_between(client:, from:, to:) -> Array<Hash>
  #
  # Returns the documents present in WorkplaceSearch that were last modified within
  # the given time window
  #
  # @param [WorkplaceSearchClient] client The client for calling WorkplaceSearch.
  # @param [Time] from The start of the time window.
  # @param [Time] to The end of the time window.
  # @return [Array<Hash>] The documents modified within the time window.
  def documents_modified_between(client:, from:, to:)
    response = client.search(
      {
        filters: {
          all: [
            {
              content_source_id: id
            },
            {
              last_activity_at: {
                from: from.iso8601,
                to: to.iso8601
              }
            }
          ]
        },
        result_fields: {
          gitlab_id: { raw: {} },
          project_id: { raw: {} },
          type: { raw: {} }
        }
      }
    )

    raise "Failed to query for documents from #{from} to #{to} because #{response.status}: #{response.body}" unless response.status.ok?

    JSON.parse(response.body)['results'].map do |next_document|
      {
        id: next_document.dig('id', 'raw'),
        gitlab_id: next_document.dig('gitlab_id', 'raw'),
        project_id: next_document.dig('project_id', 'raw'),
        type: next_document.dig('type', 'raw')
      }
    end
  end

  # index(client:, documents:) -> Number
  #
  # Indexes the given documents into WorkplaceSearch.
  #
  # @param [WorkplaceSearchClient] client The client for calling WorkplaceSearch.
  # @param [Array<Hash>] documents The documents to write.
  # @return [Number] The number of documents written.
  def index(client:, documents:)
    documents.each_slice(batch_size).each do |next_batch|
      response = client.post("/api/ws/v1/sources/#{id}/documents/bulk_create", next_batch)

      raise "Failed to index batch of #{documents.size} documents because #{response.status}: #{response.body}" unless response.status.ok?
    end

    documents.size
  end

  private

  def batch_size
    100
  end
end