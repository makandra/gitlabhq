require 'spec_helper'

describe "MergeRequests" do
  let(:project) { Factory :project }
  let(:assignee) { Factory :user }
  let(:team_member) { Factory :user }

  before do
    login_as :user
    project.add_access(@user, :read, :write)
    project.add_access(assignee, :read, :write)
    project.add_access(team_member, :read, :write)
    @merge_request = Factory :merge_request,
      :author => @user,
      :assignee => assignee,
      :project => project

    ActionMailer::Base.deliveries.clear
  end

  describe "add new note and notify involved" do 
    before do
      visit project_merge_request_path(project, @merge_request.id)
      fill_in "note_note", :with => "My note" 
    end

    it 'should only send a mail to the assignee' do
      click_button "Add Comment"
      ActionMailer::Base.deliveries.should have(1).mail
      email = ActionMailer::Base.deliveries.last
      email.subject.should have_content("gitlab | note for merge request")
      email.to.should include(assignee.email)
    end

    it 'should send mails to user who wrote notes' do
      Factory :note, 
        :project => project,
        :noteable => @merge_request,
        :author => team_member
      click_button "Add Comment"
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
      click_button "Add Comment"
    end

    it 'should only send a mail to the assignee' do
      ActionMailer::Base.deliveries.should have(2).mails
      emails = ActionMailer::Base.deliveries
      emails.collect(&:to).should =~ [[assignee.email], [team_member.email]]
    end

  end
end
