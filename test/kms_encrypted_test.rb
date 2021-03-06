require_relative "test_helper"

class KmsEncryptedTest < Minitest::Test
  def setup
    User.delete_all
    create_user
  end

  def test_create
    user = create_user
    assert_equal "test@example.org", user.email
    assert_equal "555-555-5555", user.phone
  end

  def test_read
    user = User.last
    assert_equal "test@example.org", user.email
    assert_equal "555-555-5555", user.phone
  end

  def test_update_does_not_decrypt
    assert_operations generate_data_key: 1 do
      user = User.last
      user.encrypted_kms_key = nil
      user.encrypted_email = nil
      ActiveSupport::Deprecation.silence do
        user.update!(email: "test@example.org")
      end
    end
  end

  def test_reload_clears_data_key_cache
    assert_operations decrypt_data_key: 2 do
      user = User.last
      user.email
      user.reload
      user.email
    end
  end

  def test_rotate
    user = User.last
    fields = user.attributes
    user.rotate_kms_key!

    %w(encrypted_email encrypted_email_iv encrypted_kms_key).each do |attr|
      assert user.send(attr) != fields[attr], "#{attr} expected to change"
    end

    user.reload
    assert_equal "test@example.org", user.email
  end

  def test_rotate_phone
    user = User.last
    fields = user.attributes
    user.rotate_kms_key_phone!

    %w(encrypted_phone encrypted_phone_iv encrypted_kms_key_phone).each do |attr|
      assert user.send(attr) != fields[attr], "#{attr} expected to change"
    end

    user.reload
    assert_equal "555-555-5555", user.phone
  end

  def test_kms_keys
    assert User.kms_keys[:kms_key]
    assert User.kms_keys[:kms_key_phone]
  end

  private

  def assert_operations(expected)
    $events.clear
    yield
    assert_equal expected, $events
  end

  def create_user
    # for now
    ActiveSupport::Deprecation.silence do
      User.create!(name: "Test", email: "test@example.org", phone: "555-555-5555")
    end
  end
end
