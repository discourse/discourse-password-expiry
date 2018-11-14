export default {
  shouldRender(args, component) {
    return !!component.get("currentUser.password_expiry_warning");
  },

  setupComponent(args, component) {
    component.set(
      "daysLeft",
      Math.ceil(
        moment(component.get("currentUser.password_expires_at")).diff(
          moment(),
          "days",
          true
        )
      )
    );

    component.set(
      "expired",
      moment().isAfter(moment(component.get("currentUser.password_expires_at")))
    );
  }
};
