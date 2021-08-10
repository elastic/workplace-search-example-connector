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

  def deindex(client:, ids:)
    ids.each_slice(batch_size).each do |next_batch|
      response = client.post("/api/ws/v1/sources/#{id}/documents/bulk_destroy", next_batch)

      raise "Failed to delete batch of #{ids.size} documents because #{response.status}: #{response.body}" unless response.status.ok?
    end

    ids.size
  end

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