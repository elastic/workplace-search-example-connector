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

require 'base64'
require 'gitlab'
require_relative 'content_source'
require_relative 'workplace_search_client'

class GitLabIndexer

  def initialize(
    gitlab_host:,
    gitlab_token:,
    workplace_search_host:,
    workplace_search_access_token:,
    workplace_search_api_access_token: nil,
    content_source_id:
  )
    Gitlab.configure do |config|
      config.endpoint = gitlab_host
      config.private_token = gitlab_token
    end
    @workplace_search_client = WorkplaceSearchClient.new(
      host: workplace_search_host,
      access_token: workplace_search_access_token,
      search_access_token: workplace_search_api_access_token
    )
    @content_source = ContentSource.new(id: content_source_id)
  end

  # index(from:, to:) -> Number
  #
  # Indexes documents that have been modified within the time window.
  # This document will query GitLab for all documents modified within the time window.
  # Each matching document will be transformed appropriately for GitLab and indexed into
  # Workplace Search.
  #
  # @param [Time] from The start of the time window.
  # @param [Time] to The end of the time window.
  # @return [Number] The number of documents indexed.
  def index(from:, to:)
    document_count = 0

    # Fetch the projects modified inside the time window
    projects = Gitlab.projects(last_activity_after: from.iso8601, last_activity_before: to.iso8601, membership: true).auto_paginate
    # Then index them, along with their readmes, issues, and merge requests.
    document_count += index_projects(projects)
    document_count += index_readmes(projects)
    document_count += index_issues(projects, from, to)
    document_count += index_merge_requests(projects, from, to)

    document_count
  end

  # cleanup(from:, to:) -> Number
  #
  # Deletes from WorkplaceSearch any documents that no longer exist in GitLab for a given time window.
  # All documents that were last indexed within the time window will be checked for existence in GitLab.
  # If they are no longer present they will be removed from WorkplaceSearch.
  #
  # @param [Time] from The start of the time window.
  # @param [Time] to The end of the time window.
  # @return [Number] The number of documents cleaned up.
  def cleanup(from:, to:)
    # Query for all documents that were indexed into Workplace Search within the time window
    documents = @content_source.documents_modified_between(client: @workplace_search_client, from: from, to: to)

    # Then check which documents still exist in GitLab
    to_delete = documents.group_by {|document| document[:type]}.map do |type, documents_of_type|
      documents_of_type.select do |next_document|
        !exists_in_gitlab?(type, next_document)
      end
    end.flatten

    # And delete the ones that do not
    @content_source.deindex(
      client: @workplace_search_client,
      ids: to_delete.map {|next_document| next_document[:id]}
    )
  end

  private

  # exists_in_gitlab?(type, document) -> Boolean
  #
  # Determines if a document of a given type is still present in GitLab.
  #
  # @param [String] type The type of the document
  # @param [Hash] document The document whose existence is being determined
  # @return [Boolean] True if the document exists in GitLab, false if not.
  def exists_in_gitlab?(type, document)
    begin
      case type
      when issue_type
        Gitlab.issue(document[:project_id], document[:gitlab_id])
      when merge_request_type
        Gitlab.merge_request(document[:project_id], document[:gitlab_id])
      when project_type
        Gitlab.project(document[:id])
      when readme_type
        project_readme(document[:project_id])
      else
        raise "Checking for existence of unknown type: #{type}"
      end
      true
    rescue Gitlab::Error::NotFound => e
      false
    end
  end

  # index_documents(documents) -> Number
  #
  # Inserts the given documents into Workplace Search.
  #
  # @param [Array<Hash>] documents The documents to insert into WorkplaceSearch.
  # @return [Number] The number of documents written.
  def index_documents(documents)
    count = 0

    loop do
      count += @content_source.index(
        client: @workplace_search_client,
        documents: documents.map do |next_result|
          yield(next_result)
        end
      )

      if documents.has_next_page?
        documents.next_page
      else
        break
      end
    end

    count
  end

  def index_issues(projects, from, to)
    issue_count = 0

    projects.each do |next_project|
      issues = Gitlab.issues(next_project.id, updated_after: from.iso8601, updated_before: to.iso8601, scope: 'all')

      issue_count += index_documents(issues) do |next_issue|
        {
          id: next_issue.id,
          gitlab_id: next_issue.iid,
          project_id: next_issue.project_id,
          name: next_issue.title,
          description: next_issue.description,
          created_at: next_issue.created_at,
          last_activity_at: next_issue.updated_at,
          url: next_issue.web_url,
          type: issue_type
        }
      end
    end

    issue_count
  end

  def index_merge_requests(projects, from, to)
    count = 0

    projects.each do |next_project|
      merge_requests = Gitlab.merge_requests(next_project.id, updated_after: from.iso8601, updated_before: to.iso8601, scope: 'all')

      count += index_documents(merge_requests) do |next_merge_request|
        {
          id: next_merge_request.id,
          gitlab_id: next_merge_request.iid,
          project_id: next_merge_request.project_id,
          name: next_merge_request.title,
          description: next_merge_request.description,
          created_at: next_merge_request.created_at,
          last_activity_at: next_merge_request.updated_at,
          url: next_merge_request.web_url,
          type: merge_request_type
        }
      end
    end

    count
  end

  def index_projects(projects)
    @content_source.index(
      client: @workplace_search_client,
      documents: projects.map do |next_project|
        {
          id: next_project.id,
          name: next_project.name,
          description: next_project.description,
          created_at: next_project.created_at,
          last_activity_at: next_project.last_activity_at,
          url: next_project.web_url,
          type: project_type
        }
      end
    )
  end

  def index_readmes(projects)
    @content_source.index(
      client: @workplace_search_client,
      documents: projects.map do |next_project|
        begin
          readme = project_readme(next_project.id)
          {
            id: readme.blob_id,
            project_id: next_project.id,
            name: readme.file_name,
            description: "#{next_project.name} README",
            url: next_project.readme_url,
            content: Base64.decode64(readme.content),
            type: readme_type
          }
        rescue Gitlab::Error::NotFound => e
          # Project does not have a README. Skip.
          nil
        end
      end.compact
    )
  end

  def project_readme(project_id)
    Gitlab.get_file(project_id, 'README.md', 'master')
  end

  def issue_type
    'issue'
  end

  def merge_request_type
    'merge request'
  end

  def project_type
    'project'
  end

  def readme_type
    'readme'
  end

end