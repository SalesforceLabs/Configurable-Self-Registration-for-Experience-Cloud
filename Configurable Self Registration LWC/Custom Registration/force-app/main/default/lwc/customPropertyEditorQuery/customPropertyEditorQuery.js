import { LightningElement, api } from "lwc";

export default class CustomPropertyEditorQuery extends LightningElement {
	@api value;

	handleChange(event) {
		this.value = event.detail.value;
		this.dispatchEvent(new CustomEvent("valuechange", { detail: { value: this.value } }));
	}
}
