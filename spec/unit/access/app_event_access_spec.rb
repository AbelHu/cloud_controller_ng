require 'spec_helper'

describe AppEventAccess, type: :access do
  subject(:access) { AppEventAccess.new(Security::AccessContext.new) }
  let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }

  let(:user) { User.make }
  let(:org) { Organization.make }
  let(:space) { Space.make(organization: org) }
  let(:app) { AppFactory.make(space: space) }
  let(:object) { AppEvent.make(app: app) }

  before do
    SecurityContext.set(user, token)
  end

  after do
    SecurityContext.clear
  end

  it_should_behave_like :admin_full_access

  context 'organization manager' do
    before { org.add_manager(user) }
    it_behaves_like :read_only_access
  end

  context 'organization user' do
    before { org.add_user(user) }
    it_behaves_like :no_access
  end

  context 'organization auditor' do
    before { org.add_auditor(user) }
    it_behaves_like :no_access
  end

  context 'billing manager' do
    before { org.add_billing_manager(user) }
    it_behaves_like :no_access
  end

  context 'space developer' do
    before do
      org.add_user(user)
      space.add_developer(user)
    end
    it_behaves_like :read_only_access
  end

  context 'space manager' do
    before do
      org.add_user(user)
      space.add_manager(user)
    end
    it_behaves_like :read_only_access
  end

  context 'space auditor' do
    before do
      org.add_user(user)
      space.add_auditor(user)
    end
    it_behaves_like :read_only_access
  end

  context 'user in a different organization (defensive)' do
    before do
      different_organization = Organization.make
      different_organization.add_user(user)
    end

    it_behaves_like :no_access
  end

  context 'manager in a different organization (defensive)' do
    before do
      different_organization = Organization.make
      different_organization.add_manager(user)
    end

    it_behaves_like :no_access
  end

  context 'a user that isnt logged in (defensive)' do
    let(:user) { nil }
    it_behaves_like :no_access
  end

  context 'any user using client without cloud_controller.write' do
    let(:token) { { 'scope' => ['cloud_controller.read'] } }
    before do
      org.add_user(user)
      org.add_manager(user)
      org.add_billing_manager(user)
      org.add_auditor(user)
      space.add_manager(user)
      space.add_developer(user)
      space.add_auditor(user)
    end

    it_behaves_like :read_only_access
  end

  context 'any user using client without cloud_controller.read' do
    let(:token) { { 'scope' => [] } }
    before do
      org.add_user(user)
      org.add_manager(user)
      org.add_billing_manager(user)
      org.add_auditor(user)
      space.add_manager(user)
      space.add_developer(user)
      space.add_auditor(user)
    end

    it_behaves_like :no_access
  end
end
