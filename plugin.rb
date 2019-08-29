# frozen_string_literal: true

# name: discourse-password-expiry
# about: Force users to change their password on a periodic basis
# version: 1.0
# authors: David Taylor
# url: https://github.com/discourse/discourse-password-expire

enabled_site_setting :password_expiry_enabled

after_initialize do
  add_to_serializer(:current_user, :password_expires_at) do
    object.password_expires_at
  end

  add_to_serializer(:current_user, :password_expiry_warning) do
    return false if object.anonymous? || object.try(:is_anonymous_user)
    object.password_expires_at - Time.zone.now < SiteSetting.password_expiry_warning_days.days
  end

  add_to_class(:user, :password_expires_at) do
    last_changed = UserHistory.for(self, :change_password).order('created_at DESC').first&.created_at || created_at
    last_changed + SiteSetting.password_expiry_days.days
  end

  reloadable_patch do
    module ::PasswordExpiryNotificationExtension
      def password_expiry(user, opts = {})
        build_email(
          user.email,
          template: "user_notifications.password_expiry",
          locale: user_locale(user),
          email_token: opts[:email_token],
          count: ((user.password_expires_at - Time.now) / 1.day).ceil
        )
      end
    end

    ::UserNotifications.class_eval do
      prepend PasswordExpiryNotificationExtension
    end

    module ::LoginErrorCheckExpire
      private
      def login_error_check(user)
        return super unless SiteSetting.password_expiry_enabled
        return { error: I18n.t("login.password_expired") } if Time.zone.now > user.password_expires_at
        super
      end
    end

    ::SessionController.class_eval do
      prepend LoginErrorCheckExpire
    end
  end

  module ::Jobs
    class SendPasswordExpiryReminders < Jobs::Scheduled
      every 1.hour

      def execute(args)
        return unless SiteSetting.password_expiry_enabled

        expiry_threshold = Time.zone.now - SiteSetting.password_expiry_days.days
        days_before = SiteSetting.password_expiry_message_days.split("|").map(&:to_i).sort

        sql = <<~SQL
          SELECT id, last_changed, last_emailed FROM (
            SELECT users.id as id, COALESCE(max(uh.created_at), users.created_at) as last_changed, max(ucf.value::timestamp) as last_emailed
            FROM users
            LEFT JOIN user_histories uh
              ON uh.target_user_id = users.id AND uh.action = :action_id
            LEFT JOIN user_custom_fields ucf
              ON ucf.user_id = users.id AND ucf.name = :custom_field_name
            GROUP BY users.id
          ) x
          WHERE last_changed < :last_changed_before
          AND last_changed > :last_changed_after
          AND (last_emailed < last_changed OR last_emailed IS NULL)
        SQL

        days_before.each do |day|
          custom_field_name = "password_reminder_day_#{day}"
          users_to_message = DB.query(sql,
            action_id: UserHistory.actions[:change_password],
            last_changed_after: expiry_threshold + day.days - 1.day,
            last_changed_before: expiry_threshold + day.days,
            custom_field_name: custom_field_name)
          users_to_message.each do |row|
            user = User.find(row.id)
            next if user.try(:is_anonymous_user) # From github.com/discourse/discourse-anonymous-user
            next if user.anonymous? # From core anonymous feature
            next if user.staged?
            next unless user.active

            email_token = user.email_tokens.create(email: user.email)
            Jobs.enqueue(:critical_user_email, type: :password_expiry,
                                               user_id: user.id,
                                               email_token: email_token.token
                                              )

            UserCustomField.find_or_create_by!(user: user, name: custom_field_name).update(value: Time.zone.now)
          end
        end
      end
    end
  end
end
