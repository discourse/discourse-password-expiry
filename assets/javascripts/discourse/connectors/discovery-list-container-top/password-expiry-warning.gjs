import Component from "@glimmer/component";
import { service } from "@ember/service";
import PasswordExpiryWarning from "../../components/password-expiry-warning";

export default class extends Component {
  @service currentUser;

  <template>
    {{#if this.currentUser.password_expiry_warning}}
      <PasswordExpiryWarning />
    {{/if}}
  </template>
}
