require 'rails_helper'

RSpec.describe GroupAssignmentRepo, type: :model do
  fixtures :groupings, :group_assignments, :organizations, :users

  context 'with created objects', :vcr do
    let(:group_assignment) { group_assignments(:private_group_assignment_with_starter_code) }
    let(:organization)     { group_assignment.organization                                  }
    let(:grouping)         { group_assignment.grouping                                      }

    let(:student) { users(:classroom_member) }

    let(:repo_access) { RepoAccess.create(user: student, organization: organization) }
    let(:group)       { Group.create(title: 'Group 1', grouping: grouping)           }

    before(:each) do
      group.repo_accesses << repo_access
      @group_assignment_repo = GroupAssignmentRepo.create(group_assignment: group_assignment, group: group)
    end

    after(:each) do
      group.destroy
      repo_access.destroy
      @group_assignment_repo.destroy if @group_assignment_repo
    end

    describe 'callbacks', :vcr do
      describe 'before_validation' do
        describe '#create_github_repository' do
          it 'creates the repository on GitHub' do
            expect(WebMock).to have_requested(:post, github_url("/organizations/#{organization.github_id}/repos"))
          end
        end

        describe '#push_starter_code' do
          it 'pushes the starter code to the GitHub repository' do
            import_github_repo_url = github_url("/repositories/#{@group_assignment_repo.github_repo_id}/import")
            expect(WebMock).to have_requested(:put, import_github_repo_url)
          end
        end

        describe '#add_team_to_github_repository' do
          it 'adds the team to the repository' do
            github_repo = GitHubRepository.new(organization.github_client, @group_assignment_repo.github_repo_id)
            add_github_team_url = github_url("/teams/#{group.github_team_id}/repos/#{github_repo.full_name}")
            expect(WebMock).to have_requested(:put, add_github_team_url)
          end
        end
      end

      describe 'before_destroy' do
        describe '#destroy_github_repository' do
          it 'deletes the repository from GitHub' do
            repo_id = @group_assignment_repo.github_repo_id
            @group_assignment_repo.destroy

            expect(WebMock).to have_requested(:delete, github_url("/repositories/#{repo_id}"))
          end
        end
      end
    end

    describe '#creator' do
      it 'returns the group assignments creator' do
        expect(@group_assignment_repo.creator).to eql(group_assignment.creator)
      end
    end
  end
end
