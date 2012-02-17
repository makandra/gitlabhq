require 'carrierwave/orm/activerecord'
require 'file_size_validator'

class Note < ActiveRecord::Base
  belongs_to :project
  belongs_to :noteable, :polymorphic => true
  belongs_to :author,
    :class_name => "User"

  delegate :name,
           :email,
           :to => :author,
           :prefix => true

  attr_protected :author, :author_id
  attr_accessor :notify
  attr_accessor :notify_author
  attr_accessor :notify_involved

  validates_presence_of :project

  validates :note,
            :presence => true,
            :length   => { :within => 0..5000 }

  validates :attachment,
            :file_size => {
              :maximum => 10.megabytes.to_i
            }

  scope :common, where(:noteable_id => nil)

  scope :today, where("created_at >= :date", :date => Date.today)
  scope :last_week, where("created_at  >= :date", :date => (Date.today - 7.days))
  scope :since, lambda { |day| where("created_at  >= :date", :date => (day)) }
  scope :fresh, order("created_at DESC")
  scope :inc_author_project, includes(:project, :author)
  scope :inc_author, includes(:author)

  mount_uploader :attachment, AttachmentUploader

  def notify
    @notify ||= false
  end

  def notify_author
    @notify_author ||= false
  end

  def notify_involved
    @notify_involved ||= false
  end

  def target
    if noteable_type == "Commit" 
      project.commit(noteable_id)
    else 
      noteable
    end
  # Temp fix to prevent app crash
  # if note commit id doesnt exist
  rescue 
    nil
  end

  def line_file_id
    @line_file_id ||= line_code.split("_")[1].to_i if line_code
  end

  def line_type_id
    @line_type_id ||= line_code.split("_").first if line_code
  end

  def line_number 
    @line_number ||= line_code.split("_").last.to_i if line_code
  end

  def for_line?(file_id, old_line, new_line)
    line_file_id == file_id && 
      ((line_type_id == "NEW" && line_number == new_line) || (line_type_id == "OLD" && line_number == old_line ))
  end
end
# == Schema Information
#
# Table name: notes
#
#  id            :integer         not null, primary key
#  note          :text
#  noteable_id   :string(255)
#  noteable_type :string(255)
#  author_id     :integer
#  created_at    :datetime
#  updated_at    :datetime
#  project_id    :integer
#  attachment    :string(255)
#  line_code     :string(255)
#

