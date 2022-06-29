import language from '@/src/mixins/i18n/language.js'

import StorageProviders from '@/src/components/storage-providers/StorageProviders.vue'
import Hardware from '@/src/components/hardware/Hardware.vue'
import Charts from '@/src/components/charts/Charts.vue'
import Footer from '@/src/components/footer/Footer.vue'

const created = function() {
	const that = this
	
	// set language
	this.setLanguage(this.$route)
}

const computed = {
	dashboardClass() {
		return this.theme + '-dashboard-' + this.themeVariety
	},
	locale() {
		return this.$store.getters['dashboard/getLocale']
	},
	theme() {
		return this.$store.getters['dashboard/getTheme']
	},
	themeVariety() {
		return this.$store.getters['dashboard/getThemeVariety']
	}
}

const watch = {
}

const mounted = async function() {
}

const methods = {
}

const destroyed = function() {
}

export default {
	mixins: [
		language
	],
	components: {
		StorageProviders,
		Hardware,
		Charts,
		Footer
	},
	directives: {
	},
	name: 'Dashboard',
	data () {
		return {
			storageProvider: null
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
