import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: 'wizard-links',
  items: Ember.A(),

  didInsertElement() {
    this.applySortable();
  },

  applySortable() {
    this.$("ul").sortable({tolerance: 'pointer'}).on('sortupdate', (e, ui) => {
      const itemId = ui.item.data('id');
      const index = ui.item.index();
      Ember.run.bind(this, this.updateItemOrder(itemId, index));
    });
  },

  updateItemOrder(itemId, newIndex) {
    const items = this.get('items');
    const item = items.findBy('id', itemId);
    items.removeObject(item);
    items.insertAt(newIndex, item);
    Ember.run.scheduleOnce('afterRender', this, () => this.applySortable());
  },

  @computed('type')
  header: (type) => `admin.wizard.${type}.header`,

  @computed('items.@each.id', 'current')
  links(items, current) {
    if (!items) return;

    return items.map((item) => {
      if (item) {
        const id = item.get('id');
        const label = item.get('label') || item.get('title');
        let link = { id, label: label || id };

        let classes = 'btn';
        if (current && item.get('id') === current.get('id')) {
          classes += ' btn-primary';
        };

        link['classes'] = classes;

        return link;
      }
    });
  },

  actions: {
    add() {
      const items = this.get('items');
      const newId = `step_${items.length + 1}`;
      const type = this.get('type');
      let params = { id: newId, isNew: true };

      if (type === 'step') {
        params['fields'] = Ember.A();
        params['actions'] = Ember.A();
      };

      const newItem = Ember.Object.create(params);
      items.pushObject(newItem);
      this.set('current', newItem);
    },

    change(itemId) {
      const items = this.get('items');
      this.set('current', items.findBy('id', itemId));
    },

    remove(itemId) {
      const items = this.get('items');
      items.removeObject(items.findBy('id', itemId));
      this.set('current', items[items.length - 1]);
    }
  }
});
