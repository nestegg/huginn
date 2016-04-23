# Huginn is designed to be a multi-User system.  Users have many Agents (and Events created by those Agents).
class User < ActiveRecord::Base
  DEVISE_MODULES = [:database_authenticatable, :registerable,
                    :recoverable, :rememberable, :trackable,
                    :validatable, :lockable, :omniauthable,
                    (ENV['REQUIRE_CONFIRMED_EMAIL'] == 'true' ? :confirmable : nil)].compact
  devise *DEVISE_MODULES

  INVITATION_CODES = [ENV['INVITATION_CODE'] || 'try-huginn']

  # Virtual attribute for authenticating by either username or email
  # This is in addition to a real persisted field like 'username'
  attr_accessor :login

  ACCESSIBLE_ATTRIBUTES = [ :email, :username, :login, :password, :password_confirmation, :remember_me, :invitation_code ]

  attr_accessible *ACCESSIBLE_ATTRIBUTES
  attr_accessible *(ACCESSIBLE_ATTRIBUTES + [:admin]), :as => :admin

  validates_presence_of :username
  validates :username, uniqueness: { case_sensitive: false }
  validates_format_of :username, :with => /\A[a-zA-Z0-9_-]{3,15}\Z/, :message => "can only contain letters, numbers, underscores, and dashes, and must be between 3 and 15 characters in length."
  validates_inclusion_of :invitation_code, :on => :create, :in => INVITATION_CODES, :message => "is not valid", if: -> { !requires_no_invitation_code? && User.using_invitation_code? }

  has_many :user_credentials, :dependent => :destroy, :inverse_of => :user, :class_name => "Huginn::UserCredential"
  has_many :events, -> { order("events.created_at desc") }, :dependent => :delete_all, :inverse_of => :user, :class_name => "Huginn::Event"
  has_many :agents, -> { order("agents.created_at desc") }, :dependent => :destroy, :inverse_of => :user, :class_name => "Huginn::Agent"
  has_many :logs, :through => :agents, :class_name => "Huginn::AgentLog"
  has_many :scenarios, :inverse_of => :user, :dependent => :destroy, :class_name => "Huginn::Scenario"
  has_many :services, -> { by_name('asc') }, :dependent => :destroy, :class_name => "Huginn::Service"

  def available_services
    Huginn::Service.available_to_user(self).by_name
  end

  # Allow users to login via either email or username.
  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    else
      where(conditions).first
    end
  end

  def active?
    !deactivated_at
  end

  def deactivate!
    User.transaction do
      agents.update_all(deactivated: true)
      update_attribute(:deactivated_at, Time.now)
    end
  end

  def activate!
    User.transaction do
      agents.update_all(deactivated: false)
      update_attribute(:deactivated_at, nil)
    end
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :deactivated_account
  end

  def self.using_invitation_code?
    ENV['SKIP_INVITATION_CODE'] != 'true'
  end

  def requires_no_invitation_code!
    @requires_no_invitation_code = true
  end

  def requires_no_invitation_code?
    !!@requires_no_invitation_code
  end
end
