class NoteObserver < ActiveRecord::Observer
  def after_create(note)
    send_notify_mails(note)
  end

  protected

  def send_notify_mails(note)
    if note.notify
      notify_users(note, note.project.users)
    elsif note.notify_involved
      notify_users(note, note.noteable.involved_users)
    elsif note.notify_author
      notify_users(note, [note.commit_author])
    else
      # Otherwise ignore it
      nil
    end
  end

  # Notifies the whole team except the author of note
  def notify_users(note, users)
    # Note: wall posts are not "attached" to anything, so fall back to "Wall"
    noteable_type = note.noteable_type.presence || "Wall"
    notify_method = "note_#{noteable_type.underscore}_email".to_sym

    if Notify.respond_to? notify_method
      users_without_note_author(users, note).map do |u|
        Notify.delay.send(notify_method, u.id, note.id)
      end
    end
  end

  def users_without_note_author(users, note)
    users.compact.reject { |u| u.id == note.author.id }
  end
end
