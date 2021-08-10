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
require_relative '../index'

describe 'indexing' do
  let(:host) { "https://#{random_string}.com" }
  let(:access_token) { random_string }
  let(:content_source_id) { random_string }
  let(:gitlab_host) { "https://#{random_string}.com" }
  let(:gitlab_token) { random_string }
  let(:from) { Time.now.utc - 1.day }
  let(:to) { Time.now.utc - 1.hour }

  context 'projects' do
    it 'should persist each one' do
      projects = expect_projects([random_project, random_project, random_project])
      indexing_request = expect_indexing(to_api_projects(projects))

      run_index

      expect(indexing_request).to(have_been_requested)
    end

    it 'should batch into groups of 100' do
      projects = expect_projects(200.times.collect { random_project })
      indexing_requests = projects.each_slice(100).map do |next_batch|
        expect_indexing(to_api_projects(next_batch))
      end

      run_index

      indexing_requests.each { |next_request| expect(next_request).to(have_been_requested) }
    end

    it 'should propagate failures' do
      projects = expect_projects([random_project])
      when_indexing(to_api_projects(projects)).and_return(status: 500)

      expect {
        run_index
      }.to(raise_error(/because 500/))
    end

    context 'readmes' do
      it 'are indexed' do
        project = expect_projects([random_project]).first
        expect_indexing(to_api_projects([project]))
        indexing_request = expect_indexing(
          [
            to_api_readme(
              project, expect_readme(project)
            )
          ]
        )

        run_index

        expect(indexing_request).to(have_been_requested)
      end

      it 'are skipped if not present' do
        projects = expect_projects([random_project, random_project])
        expect_indexing(to_api_projects(projects))
        expect_indexing(
          [
            to_api_readme(
              projects.last, expect_readme(projects.last)
            )
          ]
        )

        expect {
          run_index
        }.to_not(raise_error)
      end
    end

    context 'issues' do
      it 'are indexed' do
        project = expect_projects([random_project]).first
        expect_indexing(to_api_projects([project]))
        indexing_request = expect_indexing(
          to_api_issues(
            expect_issues(project, [random_issue, random_issue, random_issue])
          )
        )

        run_index

        expect(indexing_request).to(have_been_requested)
      end
    end

    context 'merge requests' do
      it 'are indexed' do
        project = expect_projects([random_project]).first
        expect_indexing(to_api_projects([project]))
        indexing_request = expect_indexing(
          to_api_merge_requests(
            expect_merge_requests(project, [random_merge_request, random_merge_request, random_merge_request])
          )
        )

        run_index

        expect(indexing_request).to(have_been_requested)
      end
    end

    def expect_indexing(documents)
      when_indexing(documents).and_return(status: 200)
    end

    def expect_issues(project, issues)
      when_list_issues(project[:id])
        .to_return(status: 200, body: issues.to_json)
      issues
    end

    def expect_merge_requests(project, merge_requests)
      when_list_merge_requests(project[:id])
        .to_return(status: 200, body: merge_requests.to_json)
      merge_requests
    end

    def expect_no_issues(project_id)
      when_list_issues(project_id).and_return(status: 200, body: [].to_json)
    end

    def expect_no_merge_requests(project_id)
      when_list_merge_requests(project_id).and_return(status: 200, body: [].to_json)
    end

    def expect_no_readme(project_id)
      when_get_readme(project_id).and_return(status: 404)
    end

    def expect_readme(project)
      expect_readmes([project]).first
    end

    def expect_readmes(projects)
      projects.map do |next_project|
        readme = random_readme
        when_get_readme(next_project[:id])
          .and_return(status: 200, body: readme.to_json)
        readme
      end
    end

    def expect_projects(projects)
      when_list_projects
        .to_return(status: 200, body: projects.to_json)

      projects.each do |next_project|
        expect_no_readme(next_project[:id])
        expect_no_issues(next_project[:id])
        expect_no_merge_requests(next_project[:id])
      end

      projects
    end

    def run_index
      index(
        host: host,
        access_token: access_token,
        content_source_id: content_source_id,
        gitlab_host: gitlab_host,
        gitlab_token: gitlab_token,
        from: from.iso8601,
        to: to.iso8601
      )
    end

    def to_api_issues(issues)
      issues.map do |next_issue|
        {
          id: next_issue[:id],
          gitlab_id: next_issue[:iid],
          project_id: next_issue[:project_id],
          name: next_issue[:title],
          description: next_issue[:description],
          created_at: next_issue[:created_at],
          last_activity_at: next_issue[:updated_at],
          url: next_issue[:web_url],
          type: 'issue'
        }
      end
    end

    def to_api_merge_requests(merge_requests)
      merge_requests.map do |next_merge_request|
        {
          id: next_merge_request[:id],
          gitlab_id: next_merge_request[:iid],
          project_id: next_merge_request[:project_id],
          name: next_merge_request[:title],
          description: next_merge_request[:description],
          created_at: next_merge_request[:created_at],
          last_activity_at: next_merge_request[:updated_at],
          url: next_merge_request[:web_url],
          type: 'merge request'
        }
      end
    end

    def to_api_projects(projects)
      projects.map do |next_project|
        {
          id: next_project[:id],
          name: next_project[:name],
          description: next_project[:description],
          created_at: next_project[:created_at],
          last_activity_at: next_project[:last_activity_at],
          url: next_project[:web_url],
          type: 'project'
        }
      end
    end

    def to_api_readme(project, readme)
      {
        id: readme[:blob_id],
        project_id: project[:id],
        name: readme[:file_name],
        description: "#{project[:name]} README",
        url: project[:readme_url],
        content: Base64.decode64(readme[:content]),
        type: 'readme'
      }
    end

    def when_get_readme(project_id)
      stub_request(:get, "#{gitlab_host}/projects/#{project_id}/repository/files/README.md?ref=master")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end

    def when_indexing(documents)
      stub_request(:post, "#{host}/api/ws/v1/sources/#{content_source_id}/documents/bulk_create")
        .with(
          headers: {
            "Authorization" => "Bearer #{access_token}"
          },
          body: documents.to_json
        )
    end

    def when_list_issues(project_id)
      stub_request(:get, "#{gitlab_host}/projects/#{project_id}/issues?updated_after=#{from.iso8601}&updated_before=#{to.iso8601}&scope=all")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end

    def when_list_merge_requests(project_id)
      stub_request(:get, "#{gitlab_host}/projects/#{project_id}/merge_requests?updated_after=#{from.iso8601}&updated_before=#{to.iso8601}&scope=all")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end

    def when_list_projects
      stub_request(:get, "#{gitlab_host}/projects?last_activity_after=#{from.iso8601}&last_activity_before=#{to.iso8601}&membership=true")
        .with(
          headers: {
            'Authorization' => "Bearer #{gitlab_token}"
          }
        )
    end
  end
end