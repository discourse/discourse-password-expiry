import { default as computed } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Component.extend({
  changing: false,
  changed: false,
  sentToEmail: "",

  @computed("currentUser.password_expires_at")
  daysLeft(passwordExpiresAt) {
    return Math.ceil(moment(passwordExpiresAt).diff(moment(), "days", true));
  },

  @computed("currentUser.password_expires_at")
  expired(passwordExpiresAt) {
    return moment().isAfter(moment(passwordExpiresAt));
  },

  actions: {
    changePassword() {
      this.set("changing", true);
      this.currentUser.findDetails().then(user => {
        this.set("sentToEmail", user.email);
        user
          .changePassword()
          .then(() => this.set("changed", true))
          .catch(popupAjaxError)
          .finally(() => this.set("changing", false));
      });
    }
  }
});
