require 'test_helper'

class SessionLimitableEvaluator
  RecordDBColumnsMisconfiguration = Class.new(StandardError)

  attr_reader :record
  attr_accessor :unique_session_id, :user_agent, :remote_ip

  def initialize(record)
    @record = record
  end

  def evaluate_sign_in
    if record_uses_session_limitable_module?
      ensure_field_existance
      yield
    end
  end

  def evaluate_unauthorized_access
    if record_uses_session_limitable_module?
      ensure_field_existance
      if restricted_by_unique_session_id? || restricted_by_ip? || restricted_by_user_agent?
        yield
      end
    end
  end

  private

  def restricted_by_unique_session_id?
    RestrictedBySubmodule
      .new(session_limitable_on_unique_id?)
      .call { record.unique_session_id != unique_session_id }
  end

  def restricted_by_ip?
    RestrictedBySubmodule
      .new(session_limitable_on_unique_id?)
      .call { record.unique_session_id != unique_session_id }
  end

  def restricted_by_user_agent?
    RestrictedBySubmodule
      .new(session_limitable_on_unique_id?)
      .call { record.unique_session_id != unique_session_id }
  end

  RestrictedBySubmodule = Struct.new(:use_submodule) do
    def call
      if use_submodule
        yield
      else
        false
      end
    end
  end

  # When record includes module SessionLimitable
  #
  #     class User < ActiveRecord::Base
  #        devise :session_limitable # ...
  #     end
  #
  # ...it will `add update_unique_session_id!` method to model
  def record_uses_session_limitable_module?
    record.respond_to?(:update_unique_session_id!)
  end

  def ensure_field_existance
    if session_limitable_on_unique_id? && !record.respond_to?(:unique_session_id)
      raise RecordDBColumnsMisconfiguration, 'unique_session_id column is missing'
    end
  end

  def session_limitable_on_unique_id?
    Devise.session_limitable_on_unique_id
  end

  def session_limitable_on_ip?
    Devise.session_limitable_on_ip
  end

  def session_limitable_on_user_agent?
    Devise.session_limitable_on_user_agent
  end

  #if warden.authenticated?(scope) \
      #&& options[:store] != false \
      #&& record.respond_to?(:current_user_agent) \
      #&& record.respond_to?(:current_sign_in_ip)

    #if record.current_user_agent != warden.request.user_agent || record.current_sign_in_ip != warden.request.remote_ip
      #warden.logout(scope)
      #throw :warden, :scope => scope, :message => :session_non_transferable
    #end
  #end
  #
  #
  #
  #
  #
  #
  #
  #

  #
  #def validate_record_database_integrity
    #unless session_limitable_on_unique_id? && record.respond_to?(:unique_session_id)
      #raise RecordDBColumnsMisconfiguration, "unique_session_id doesn't exist"
    #end
  #end
end


class TestSessionLimitableLogic < ActiveSupport::TestCase
  Struct.new('MisconfiguredSessionLimitableRecord') do
    def update_unique_session_id!
    end
  end

  Struct.new('RecordUsingSessionLimitable') do
    def update_unique_session_id!
    end

    # this represents value in DB column
    def unique_session_id
      'valid-session-id'
    end
  end

  Struct.new('RecordNotUsingSessionLimitable') do

    # this represents value in DB column
    def unique_session_id
      'valid-session-id'
    end
  end

  attr_reader :described_class

  def setup
    @described_class = SessionLimitableEvaluator
    @spy_result = "not-called"
  end

  test 'evaluate_sign_in should call block when record uses SessionLimitable module' do
    record = Struct::RecordUsingSessionLimitable.new
    evaluator = described_class.new(record)

    evaluator.evaluate_sign_in do
      @spy_result = 'called'
    end

    assert_equal(@spy_result, 'called')
  end

  test 'evaluate_sign_in should not call block when record is not using SessionLimitable module' do
    record = Struct::RecordNotUsingSessionLimitable.new
    evaluator = described_class.new(record)

    evaluator.evaluate_sign_in do
      @spy_result = 'called'
    end

    assert_equal(@spy_result, 'not-called')
  end

  test 'evaluate_sign_in should raise error when record uses SessionLimitable module but have not required DB columns' do
    record = Struct::MisconfiguredSessionLimitableRecord.new
    evaluator = described_class.new(record)

    assert_raise(SessionLimitableEvaluator::RecordDBColumnsMisconfiguration) do
      evaluator.evaluate_sign_in {}
    end
  end

  test 'evaluate_unauthorized_access should not call block when not using SessionLimitable module' do
    record = Struct::RecordNotUsingSessionLimitable.new
    evaluator = described_class.new(record)

    evaluator.evaluate_unauthorized_access do
      @spy_result = 'loggout called'
    end

    assert_equal(@spy_result, 'not-called')
  end

  test 'evaluate_unauthorized_access should not call block when record when unique session id match' do
    record = Struct::RecordUsingSessionLimitable.new
    evaluator = described_class.new(record)
    evaluator.unique_session_id = 'valid-session-id'

    evaluator.evaluate_unauthorized_access do
      @spy_result = 'loggout called'
    end

    assert_equal(@spy_result, 'not-called')
  end

  test "evaluate_unauthorized_access should call block when record when unique session id don't match" do
    record = Struct::RecordUsingSessionLimitable.new
    evaluator = described_class.new(record)
    evaluator.unique_session_id = 'invalid-session-id'

    evaluator.evaluate_unauthorized_access do
      @spy_result = 'loggout called'
    end

    assert_equal(@spy_result, 'loggout called')
  end


end
