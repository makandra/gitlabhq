require 'spec_helper'

describe NoteObserver do
  subject { NoteObserver.instance }

  let(:users) { (1..3).map { |n| double :user, id: n } }
  let(:users_without_author) { (1..2).map { |n| double :user, id: n } }
  let(:delivery_success) { double deliver: true }

  describe '#after_create' do
    let(:note) { double :note }

    it 'is called after a note is created' do
      subject.should_receive :after_create

      Note.observers.enable :note_observer do
        create(:note)
      end
    end

    it 'sends out notifications' do
      subject.should_receive(:send_notify_mails).with(note)

      subject.after_create(note)
    end
  end

  describe "#send_notify_mails" do
    let(:note) { double :note, notify: false, notify_author: false, notify_involved: false }

    it 'notifies team of new note when flagged to notify' do
      note.stub(:notify).and_return(true)
      note.stub_chain(:project, :users).and_return(:team)
      subject.should_receive(:notify_users).with(note, :team)

      subject.after_create(note)
    end

    it 'notifies the author of a commit when flagged to notify the author' do
      note.stub(:notify_author).and_return(true)
      note.stub(:commit_author).and_return(:author)
      subject.should_receive(:notify_users).with(note, [:author])

      subject.after_create(note)
    end

    it 'notifies the involved users when flagged to notify involved users' do
      note.stub(:notify_involved).and_return(true)
      note.stub_chain(:noteable, :involved_users).and_return(:involved_users)
      subject.should_receive(:notify_users).with(note, :involved_users)
      subject.after_create(note)
    end

    it 'does not notify the author of a commit when not flagged to notify the author' do
      notify.should_not_receive(:notify_users)
      subject.after_create(note)
    end

    it 'does nothing if no notify flags are set' do
      subject.should_not_receive(:notify_users)
      subject.after_create(note).should be_nil
    end
  end

  describe '#notify_users' do
    let(:note) { double :note, id: 1 }

    before :each do
      subject.stub(:users_without_note_author).with(users, note).and_return(users_without_author)
    end

    context 'notifies team of a new note on' do
      it 'a commit' do
        note.stub(:noteable_type).and_return('Commit')
        notify.should_receive(:note_commit_email).twice

        subject.send(:notify_users, note, users)
      end

      it 'an issue' do
        note.stub(:noteable_type).and_return('Issue')
        notify.should_receive(:note_issue_email).twice

        subject.send(:notify_users, note, users)
      end

      it 'a wiki page' do
        note.stub(:noteable_type).and_return('Wiki')
        notify.should_receive(:note_wiki_email).twice

        subject.send(:notify_users, note, users)
      end

      it 'a merge request' do
        note.stub(:noteable_type).and_return('MergeRequest')
        notify.should_receive(:note_merge_request_email).twice

        subject.send(:notify_users, note, users)
      end

      it 'a wall' do
        # Note: wall posts have #noteable_type of nil
        note.stub(:noteable_type).and_return(nil)
        notify.should_receive(:note_wall_email).twice

        subject.send(:notify_users, note, users)
      end
    end

    it 'does nothing for a new note on a snippet' do
      note.stub(:noteable_type).and_return('Snippet')

      subject.send(:notify_users, note, users).should be_nil
    end
  end


  describe '#users_without_note_author' do
    let(:author) { double :user, id: 3 }
    let(:note) { double :note, author: author }

    it 'returns the projects user without the note author included' do
      subject.send(:users_without_note_author, users, note).map(&:id).should == users_without_author.map(&:id)
    end
  end

  def notify
    Notify
  end
end
