require 'spec_helper'

describe "MergeRequests" do
  let(:project) { create :project }
  let(:assignee) { create :user }
  let(:team_member) { create :user }

  before do
    login_as :user
    project.add_access(@user, :read, :write)
    project.add_access(assignee, :read, :write)
    project.add_access(team_member, :read, :write)
    @merge_request = create :merge_request,
      :author => @user,
      :assignee => assignee,
      :project => project

    Notify.deliveries.clear
  end

  describe "add new note and notify involved" do 
    before do
      visit project_merge_request_path(project, @merge_request.id)
      fill_in "note_note", :with => "My note" 
    end

    it 'should only send a mail to the assignee' do
      with_resque do
        Note.observers.enable :note_observer do
          click_button "Add Comment"
        end
      end
      ActionMailer::Base.deliveries.should have(1).mail
      email = ActionMailer::Base.deliveries.last
      email.subject.should have_content("GitLab | note for merge request")
      email.to.should include(assignee.email)
    end

    it 'should send mails to user who wrote notes' do
      create :note, 
        :project => project,
        :noteable => @merge_request,
        :author => team_member
      with_resque do
        Note.observers.enable :note_observer do
          click_button "Add Comment"
        end
      end
      ActionMailer::Base.deliveries.should have(2).mail
      emails = ActionMailer::Base.deliveries
      emails.collect(&:to).should =~ [[assignee.email], [team_member.email]]
    end

  end

  describe "add new note and notify all" do 
    before do
      visit project_merge_request_path(project, @merge_request.id)
      fill_in "note_note", :with => "My note" 
      check "notify"
      with_resque do
        Note.observers.enable :note_observer do
          click_button "Add Comment"
        end
      end
    end

    it 'should only send a mail to the assignee' do
      ActionMailer::Base.deliveries.should have(2).mails
      emails = ActionMailer::Base.deliveries
      emails.collect(&:to).should =~ [[assignee.email], [team_member.email]]
    end

  end
end
