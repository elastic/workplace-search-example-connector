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

require 'spec_helper'
require_relative '../cleanup'

describe 'cleanup' do
  let(:host) { "https://#{random_string}.com" }
  let(:access_token) { random_string }
  let(:search_access_token) { random_string }
  let(:content_source_id) { random_string }
  let(:gitlab_host) { "https://#{random_string}.com" }
  let(:gitlab_token) { random_string }
  let(:from) { Time.now.utc - 1.day }
  let(:to) { Time.now.utc - 1.hour }

  context 'projects' do
    it 'are deleted if they no longer exist in the 3P service' do
      projects = expect_documents([random_project, random_project, random_project, random_project], 'project')
      expect_project_exists(projects[0])
      expect_project_deleted(projects[1])
      expect_project_deleted(projects[2])
      expect_project_exists(projects[3])
      delete_request = expect_deletes([projects[1][:id], projects[2][:id]])

      run_cleanup

      expect(delete_request).to(have_been_requested)
    end
  end

  context 'issues' do
    it 'are deleted if they no longer exist in the 3P service' do
      issues = expect_documents(4.times.collect { random_issue_document }, 'issue')
      expect_issue_exists(issues[0])
      expect_issue_deleted(issues[1])
      expect_issue_deleted(issues[2])
      expect_issue_exists(issues[3])
      delete_request = expect_deletes([issues[1][:id], issues[2][:id]])

      run_cleanup

      expect(delete_request).to(have_been_requested)
    end

    def expect_issue_deleted(issue)
      when_get_issue(issue[:project_id], issue[:gitlab_id])
        .and_return(status: 404)
    end

    def expect_issue_exists(issue)
      when_get_issue(issue[:project_id], issue[:gitlab_id])
        .and_return(status: 200, body: {}.to_json)
    end

    def when_get_issue(project_id, issue_id)
      stub_request(:get, "#{gitlab_host}/projects/#{project_id}/issues/#{issue_id}")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end
  end

  context 'merge requests' do
    it 'are deleted if they no longer exist in the 3P service' do
      merge_requests = expect_documents(4.times.collect { random_merge_request_document }, 'merge request')
      expect_merge_request_exists(merge_requests[0])
      expect_merge_request_deleted(merge_requests[1])
      expect_merge_request_deleted(merge_requests[2])
      expect_merge_request_exists(merge_requests[3])
      delete_request = expect_deletes([merge_requests[1][:id], merge_requests[2][:id]])

      run_cleanup

      expect(delete_request).to(have_been_requested)
    end

    def expect_merge_request_deleted(merge_request)
      when_get_merge_request(merge_request[:project_id], merge_request[:gitlab_id])
        .and_return(status: 404)
    end

    def expect_merge_request_exists(merge_request)
      when_get_merge_request(merge_request[:project_id], merge_request[:gitlab_id])
        .and_return(status: 200, body: {}.to_json)
    end

    def when_get_merge_request(project_id, id)
      stub_request(:get, "#{gitlab_host}/projects/#{project_id}/merge_requests/#{id}")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end
  end

  context 'readmes' do
    it 'are deleted if they no longer exist in the 3P service' do
      readmes = expect_documents([random_readme_document, random_readme_document, random_readme_document, random_readme_document], 'readme')
      expect_readme_exists(readmes[0])
      expect_readme_deleted(readmes[1])
      expect_readme_deleted(readmes[2])
      expect_readme_exists(readmes[3])
      delete_request = expect_deletes([readmes[1][:id], readmes[2][:id]])

      run_cleanup

      expect(delete_request).to(have_been_requested)
    end

    def expect_readme_deleted(readme)
      when_get_readme(readme[:project_id])
        .and_return(status: 404)
    end

    def expect_readme_exists(readme)
      when_get_readme(readme[:project_id])
        .and_return(status: 200, body: {}.to_json)
    end

    def when_get_readme(project_id)
      stub_request(:get, "#{gitlab_host}/projects/#{project_id}/repository/files/README.md?ref=master")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end
  end

  it 'does not fail if some documents have already been deleted' do
    projects = expect_documents([random_project], 'project')
    expect_project_deleted(projects[0])
    expect_deletes_with_response(
      [projects[0][:id]],
      [
        {
          id: projects[0][:id],
          success: false
        }
      ]
    )

    run_cleanup
  end

  private

  def expect_deletes(ids)
    expect_deletes_with_response(
      ids,
      ids.map { |id| {id: id, success: true} }.to_json
    )
  end

  def expect_deletes_with_response(ids, response)
    when_deletes(ids)
      .and_return(
        status: 200,
        body: response.to_json
      )
  end

  def expect_documents(documents, type)
    stub_request(:post, "#{host}/api/ws/v1/search")
      .with(
        headers: {
          'Authorization' => "Bearer #{search_access_token}"
        },
        body: {
          filters: {
            all: [
              {
                content_source_id: content_source_id
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
        }.to_json
      ).and_return(
        status: 200,
        body: {
          results: documents.map do |next_document|
            {
              id: {
                raw: next_document[:id]
              },
              gitlab_id: {
                raw: next_document[:gitlab_id]
              },
              project_id: {
                raw: next_document[:project_id]
              },
              type: {
                raw: type
              }
            }
          end
        }.to_json
      )
    documents
  end

  def expect_project_deleted(project)
    when_get_project(project[:id])
      .and_return(status: 404)
  end

  def expect_project_exists(project)
    when_get_project(project[:id])
      .and_return(status: 200, body: {}.to_json)
  end

  def run_cleanup
    cleanup(
      host: host,
      access_token: access_token,
      search_access_token: search_access_token,
      content_source_id: content_source_id,
      gitlab_host: gitlab_host,
      gitlab_token: gitlab_token,
      from: from.iso8601,
      to: to.iso8601
    )
  end

  def when_deletes(ids)
    stub_request(:post, "#{host}/api/ws/v1/sources/#{content_source_id}/documents/bulk_destroy")
      .with(
        headers: {
          "Authorization" => "Bearer #{access_token}"
        },
        body: ids.to_json
      )
  end

  def when_get_project(project_id)
    stub_request(:get, "#{gitlab_host}/projects/#{project_id}")
      .with(
        headers: {
          'Authorization' => "Bearer #{gitlab_token}"
        }
      )
  end
end