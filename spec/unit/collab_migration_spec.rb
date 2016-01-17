require 'rails_helper'
require_relative '../../lib/collab_migration'

RSpec.describe CollabMigration do
  fixtures :assignments, :organizations, :users

  let(:assignment)   { assignments(:private_assignment) }
  let(:organization) { assignment.organization          }
  let(:student)      { users(:classroom_member)         }

  let(:repo_access)  { RepoAccess.create(user: student, organization: organization) }

  let(:github_organization) { GitHubOrganization.new(organization.github_client, organization.github_id) }

  describe 'repo_access with an assignment_repo', :vcr do
    before(:each) do
      @assignment_repo = AssignmentRepo.create(assignment: assignment, user: student)
      @assignment_repo.update_attributes(user: nil, repo_access: repo_access)
    end

    after(:each) do
      AssignmentRepo.destroy_all
    end

    it 'adds the user as a collaborator to the assignment_repos GitHub repo' do
      CollabMigration.new(repo_access).migrate

      github_user_login = GitHubUser.new(student.github_client, student.uid).login
      add_user_request = "/repositories/#{@assignment_repo.github_repo_id}/collaborators/#{github_user_login}"

      expect(WebMock).to have_requested(:put, github_url(add_user_request)).times(2)
    end

    context 'with a `github_team_id`' do
      before(:each) do
        github_organization = GitHubOrganization.new(organization.github_client, organization.github_id)
        @github_team        = github_organization.create_team('Test Team')

        repo_access.update_attribute(:github_team_id, @github_team.id)
      end

      after(:each) do
        organization.github_client.delete_team(@github_team.id)
      end

      it 'deletes the GitHub team' do
        CollabMigration.new(repo_access).migrate
        expect(WebMock).to have_requested(:delete, github_url("/teams/#{@github_team.id}"))
      end

      it 'sets the `github_team_id` to nil' do
        expect(repo_access.github_team_id).to eq(@github_team.id)
        CollabMigration.new(repo_access).migrate

        expect(repo_access.github_team_id).to be(nil)
      end
    end
  end
end
