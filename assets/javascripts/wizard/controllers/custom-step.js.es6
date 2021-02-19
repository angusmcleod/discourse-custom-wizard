import StepController from 'wizard/controllers/step';
import getUrl from 'discourse-common/lib/get-url';

export default StepController.extend({
  actions: {
    goNext(response, nextStep) {      
      if (response.redirect_on_next) {
        window.location.href = response.redirect_on_next;
      } else if (response.refresh_required) {
        const id = this.get('wizard.id');
        window.location.href = getUrl(`/w/${id}/steps/${next}`);
      } else {
        this.transitionToRoute('custom.step', nextStep);
      }
    },

    goBack() {
      this.transitionToRoute('custom.step', this.get('step.previous'));
    },

    showMessage(message) {
      this.set('stepMessage', message);
    },

    resetWizard() {
      const id = this.get('wizard.id');
      const stepId = this.get('step.id');
      window.location.href = getUrl(`/w/${id}/steps/${stepId}?reset=true`);
    }
  }
});
