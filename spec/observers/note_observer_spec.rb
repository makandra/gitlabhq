require 'spec_helper'

describe NoteObserver do
  subject { NoteObserver.instance }
  before { subject.stub(notification: mock('NotificationService').as_null_object) }

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
      subject.should_receive(:notification)

      subject.after_create(note)
    end
  end
end
