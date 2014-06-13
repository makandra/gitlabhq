require 'spec_helper'

describe "MergeRequests" do
  let(:project) { create :project }
  let(:assignee) { create :user }
  let(:team_member) { create :user }

  before do
    login_as :user
    project.team << [@user, :master]
    project.team << [assignee, :master]
    project.team << [team_member, :master]
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
      Note.observers.enable :note_observer do
        click_button "Add Comment"
      end
      ActionMailer::Base.deliveries.should have(1).mail
      email = ActionMailer::Base.deliveries.last
      email.subject.should =~ /GitLab | project\d+ | note for merge request/
      email.to.should include(assignee.email)
    end

    it 'should send mails to user who wrote notes' do
      create :note, 
        :project => project,
        :noteable => @merge_request,
        :author => team_member
      Note.observers.enable :note_observer do
        click_button "Add Comment"
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
      Note.observers.enable :note_observer do
        click_button "Add Comment"
      end
    end

    it 'should only send a mail to the assignee' do
      ActionMailer::Base.deliveries.should have(2).mails
      emails = ActionMailer::Base.deliveries
      emails.collect(&:to).should =~ [[assignee.email], [team_member.email]]
    end

  end
end
