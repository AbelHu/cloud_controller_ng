class ProcessDelete
  def initialize(user_guid, user_email)
    @user_guid = user_guid
    @user_email = user_email
  end

  def delete(processes)
    processes = Array(processes)

    processes.each do |process|
      Repositories::ProcessEventRepository.record_delete(process, @user_guid, @user_email)
      process.destroy
    end
  end
end
