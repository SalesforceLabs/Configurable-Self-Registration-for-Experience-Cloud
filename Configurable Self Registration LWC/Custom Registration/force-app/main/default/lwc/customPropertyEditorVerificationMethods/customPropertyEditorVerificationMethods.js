import { LightningElement, wire, api } from "lwc";
import checkSMSLicence from "@salesforce/apex/SiteUtilities.checkSMSLicence";

export default class customPropertyEditorVerificationMethods extends LightningElement {
  @api value;

  //Default is Email, which is not licence based.
  verificationOptions = [{ label: "Email", value: "Email" }];

  @wire(checkSMSLicence)
  wiredRecordTypes({ error, data }) {
    if (data) {
      this.verificationOptions = [
        { label: "Email", value: "Email" },
        { label: "SMS", value: "SMS" }
      ];
    }
  }

  get options() {
    return this.verificationOptions;
  }

  handleChange(event) {
    this.value = event.detail.value;
    this.dispatchEvent(
      new CustomEvent("valuechange", { detail: { value: this.value } })
    );
  }
}
