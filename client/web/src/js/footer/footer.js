import language from '@/src/mixins/i18n/language.js'

const created = function() {
	const that = this
	
	// set language
	this.setLanguage(this.$route)
}

const computed = {
	footerClass() {
		return this.theme + '-footer-' + this.themeVariety
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
	},
	directives: {
	},
	name: 'Footer',
	data () {
		return {
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
