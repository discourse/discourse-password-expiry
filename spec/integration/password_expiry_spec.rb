# frozen_string_literal: true

require 'rails_helper'

describe "Password Expiry" do
  before do
    SiteSetting.password_expiry_enabled = true
  end

  let(:user) {
    user = Fabricate(:user, password: 'nobodyKnowsThis', active: true)
    token = user.email_tokens.find_by(email: user.email)
    EmailToken.confirm(token.token)
    user
  }

  it 'normally allows a user to log in' do
    post "/session.json", params: {
      login: user.username, password: 'nobodyKnowsThis'
    }
    expect(response.status).to eq(200)
    expect(session[:current_user_id]).to eq(user.id)
  end

  it 'fails if their password has expired, and works after resetting' do
    user.update(created_at: 1.year.ago)
    post "/session.json", params: {
      login: user.username, password: 'nobodyKnowsThis'
    }
    expect(response.status).to eq(200)
    expect(::JSON.parse(response.body)['error']).to eq(
      I18n.t("login.password_expired")
    )
    expect(session[:current_user_id]).to eq(nil)

    token = user.email_tokens.create(email: user.email).token
    put "/u/password-reset/#{token}", params: { password: 'iChangedMyPasswordAllByMyself' }
    expect(response.status).to eq(200)

    post "/session.json", params: {
      login: user.username, password: 'iChangedMyPasswordAllByMyself'
    }
    expect(response.status).to eq(200)
    expect(session[:current_user_id]).to eq(user.id)
  end

  it 'always works for email logins' do
    SiteSetting.enable_local_logins_via_email = true
    user.update(created_at: 1.year.ago)

    # Confirm password has expired
    post "/session.json", params: {
      login: user.username, password: 'nobodyKnowsThis'
    }
    expect(session[:current_user_id]).to eq(nil)

    # Now try with email login
    post "/session/email-login/#{Fabricate(:email_token, user: user).token}.json"
    expect(response.status).to eq(200)
    expect(session[:current_user_id]).to eq(user.id)
  end

  describe "warning emails" do
    before { Jobs.run_immediately! }

    it "sends a message on the defined days" do
      SiteSetting.password_expiry_days = 4
      SiteSetting.password_expiry_message_days = "3|2|1"
      user.update(created_at: 4.days.ago + 2.days + 12.hours)
      expect do
        Jobs::SendPasswordExpiryReminders.new.execute({})
      end.to change { EmailLog.count }.by(1) &
             change { ActionMailer::Base.deliveries.count }.by(1)

      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to eq(I18n.t("user_notifications.password_expiry.subject_template", email_prefix: "Discourse", count: 3))

      # Shouldn't send message twice in same day
      expect do
        Jobs::SendPasswordExpiryReminders.new.execute({})
      end.to change { EmailLog.count }.by 0

      # Should send message next day
      user.update(created_at: 4.days.ago + 1.days + 12.hours)
      expect do
        Jobs::SendPasswordExpiryReminders.new.execute({})
      end.to change { EmailLog.count }.by 1

      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to eq(I18n.t("user_notifications.password_expiry.subject_template", email_prefix: "Discourse",  count: 2))

      # Should send the same message next time the password is due to expire
      freeze_time 1.week.from_now do
        user.update(created_at: 4.days.ago + 2.days + 12.hours)
        expect do
          Jobs::SendPasswordExpiryReminders.new.execute({})
        end.to change { EmailLog.count }.by 1

        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq(I18n.t("user_notifications.password_expiry.subject_template", email_prefix: "Discourse",  count: 3))
      end

    end

  end

end
