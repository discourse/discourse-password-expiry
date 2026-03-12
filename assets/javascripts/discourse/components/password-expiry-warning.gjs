/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class PasswordExpiryWarning extends Component {
  changing = false;
  changed = false;
  sentToEmail = "";

  @computed("currentUser.password_expires_at")
  get daysLeft() {
    return Math.ceil(
      moment(this.currentUser?.password_expires_at).diff(moment(), "days", true)
    );
  }

  @computed("currentUser.password_expires_at")
  get expired() {
    return moment().isAfter(moment(this.currentUser?.password_expires_at));
  }

  @action
  async changePassword(event) {
    event.preventDefault();

    this.set("changing", true);

    try {
      const user = await this.currentUser.findDetails();

      this.set("sentToEmail", user.email);
      await user.changePassword();

      this.set("changed", true);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.set("changing", false);
    }
  }

  <template>
    <div class="row">
      <div class="alert alert-error">
        {{#if this.expired}}
          {{i18n "password_expiry.password_expired"}}
        {{else}}
          {{i18n "password_expiry.password_expire_warning" count=this.daysLeft}}
        {{/if}}

        {{#if this.changing}}
          {{i18n "password_expiry.sending_email"}}
        {{else if this.changed}}
          {{i18n "password_expiry.email_sent" email=this.sentToEmail}}
        {{else}}
          <a href {{on "click" this.changePassword}}>
            {{i18n "password_expiry.change_password"}}
          </a>
        {{/if}}
      </div>
    </div>
  </template>
}
