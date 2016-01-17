require 'rails_helper'

RSpec.describe GroupAssignmentsController, type: :controller do
  include ActiveJob::TestHelper

  fixtures :groupings, :group_assignments, :group_assignment_invitations, :organizations, :users

  let(:group_assignment) { group_assignments(:private_group_assignment_with_starter_code) }
  let(:organization)     { group_assignment.organization                                  }
  let(:user)             { organization.users.first                                       }

  before do
    sign_in(user)
  end

  describe 'GET #new', :vcr do
    it 'returns success status' do
      get :new, organization_id: organization.slug
      expect(response).to have_http_status(:success)
    end

    it 'has a new GroupAssignment' do
      get :new, organization_id: organization.slug
      expect(assigns(:group_assignment)).to_not be_nil
    end
  end

  describe 'POST #create', :vcr do
    before do
      request.env['HTTP_REFERER'] = "http://classroomtest.com/organizations/#{organization.slug}/group-assignments/new"
    end

    it 'creates a new GroupAssignment' do
      expect do
        post :create, organization_id: organization.slug,
                      group_assignment: { title: 'Learn JavaScript' },
                      grouping:         { title: 'Grouping 1'       }
      end.to change { GroupAssignment.count }
    end

    it 'does not allow groupings to be added that do not belong to the organization' do
      new_group_assignment_params = { title: 'Learn Ruby',
                                      grouping_id: groupings(:free_repos_plan_organization_grouping).id }

      expect do
        post :create, organization_id: organization.slug, group_assignment: new_group_assignment_params
      end.not_to change { GroupAssignment.count }
    end
  end

  describe 'GET #show', :vcr do
    it 'returns success status' do
      get :show, organization_id: organization.slug, id: group_assignment.slug
      expect(response).to have_http_status(:success)
    end

    it 'returns a 404 for an group_assignment with the same slug but not in the same org' do
    end
  end

  describe 'GET #edit', :vcr do
    it 'returns success status and sets the group assignment' do
      get :edit, organization_id: organization.slug, id: group_assignment.slug

      expect(response).to have_http_status(:success)
      expect(assigns(:group_assignment)).to_not be_nil
    end

    it 'returns a 404 for an group_assignment with the same slug but not in the same org' do
    end
  end

  describe 'PATCH #update', :vcr do
    it 'correctly updates the assignment' do
      options = { title: 'JavaScript Calculator' }
      patch :update, id: group_assignment.slug, organization_id: organization.slug, group_assignment: options

      expect(response).to redirect_to(organization_group_assignment_path(organization,
                                                                         GroupAssignment.find(group_assignment.id)))
    end

    it 'returns a 404 for an group_assignment with the same slug but not in the same org' do
    end
  end

  describe 'DELETE #destroy', :vcr do
    it 'sets the `deleted_at` column for the group assignment' do
      group_assignment

      expect do
        delete :destroy, id: group_assignment.slug, organization_id: organization
      end.to change { GroupAssignment.all.count }

      expect(GroupAssignment.unscoped.find(group_assignment.id).deleted_at).not_to be_nil
    end

    it 'calls the DestroyResource background job' do
      delete :destroy, id: group_assignment.slug, organization_id: organization

      assert_enqueued_jobs 1 do
        DestroyResourceJob.perform_later(group_assignment)
      end
    end

    it 'redirects back to the organization' do
      delete :destroy, id: group_assignment.slug, organization_id: organization.slug
      expect(response).to redirect_to(organization)
    end

    it 'returns a 404 for an group_assignment with the same slug but not in the same org' do
    end
  end
end
