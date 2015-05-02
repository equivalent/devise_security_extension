require 'test_helper'

class SessionLimitableEvaluator

  attr_reader :record
  attr_accessor :unique_session_id

  def initialize(record)
    @record = record
  end

  def evaluate_sign_in
    if session_limitable_on_unique_id?
      yield
    end
  end

  def evaluate_unauthorized_access
    if session_limitable_on_unique_id? && record.unique_session_id != unique_session_id
      yield
    end
  end

  private

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

  def session_limitable_on_unique_id?
    Devise.session_limitable_on_unique_id \
      && record_uses_session_limitable_module?
  end

  #RecordDBColumnsMisconfiguration = Class.new(StandardError)
  #
  #def validate_record_database_integrity
    #unless session_limitable_on_unique_id? && record.respond_to?(:unique_session_id)
      #raise RecordDBColumnsMisconfiguration, "unique_session_id doesn't exist"
    #end
  #end
end


class TestSessionLimitableLogic < ActiveSupport::TestCase
  Struct.new('RecordUsingSessionLimitable') do
    def update_unique_session_id!
    end

    # this represents value in DB column
    def unique_session_id
      'valid-session-id'
    end
  end

  Struct.new('RecordUsingNotUsingSessionLimitable') do

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
    record = Struct::RecordUsingNotUsingSessionLimitable.new
    evaluator = described_class.new(record)

    evaluator.evaluate_sign_in do
      @spy_result = 'called'
    end

    assert_equal(@spy_result, 'not-called')
  end

  test 'evaluate_unauthorized_access should not call block when record when unique session id match' do
    record = Struct::RecordUsingSessionLimitable.new
    evaluator = described_class.new(record)
    evaluator.unique_session_id = 'valid-session-id'

    evaluator.evaluate_unauthorized_access do
      @spy_result = 'called'
    end

    assert_equal(@spy_result, 'not-called')
  end

  test 'evaluate_unauthorized_access should  call block when record when unique session id dont match' do
    record = Struct::RecordUsingSessionLimitable.new
    evaluator = described_class.new(record)
    evaluator.unique_session_id = 'invalid-session-id'

    evaluator.evaluate_unauthorized_access do
      @spy_result = 'called'
    end

    assert_equal(@spy_result, 'called')
  end


end
