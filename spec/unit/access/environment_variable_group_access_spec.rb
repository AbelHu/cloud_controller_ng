require 'spec_helper'

describe EnvironmentVariableGroupAccess, type: :access do
  subject(:access) { EnvironmentVariableGroupAccess.new(Security::AccessContext.new) }
  let(:token) { { 'scope' => ['cloud_controller.read', 'cloud_controller.write'] } }
  let(:user) { User.make }
  let(:roles) { double(:roles, admin?: false, none?: false, present?: true) }
  let(:object) { FeatureFlag.make }

  before do
    SecurityContext.set(user, token)
  end

  after do
    SecurityContext.clear
  end

  it_behaves_like :admin_full_access

  context 'a user that has cloud_controller.read' do
    let(:token) { { 'scope' => ['cloud_controller.read'] } }

    it_behaves_like :read_only_access
  end

  context 'a user that does not have cloud_controller.read' do
    let(:token) { { 'scope' => [] } }

    it_behaves_like :no_access
  end

  context 'a user that isnt logged in (defensive)' do
    let(:token) { { 'scope' => [] } }
    let(:user) { nil }
    let(:roles) { double(:roles, admin?: false, none?: true, present?: false) }

    it_behaves_like :no_access
  end
end
