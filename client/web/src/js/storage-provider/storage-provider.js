import language from '@/src/mixins/i18n/language.js'
import api from '@/src/mixins/api/api.js'

import axios from 'axios'

const created = function() {
	const that = this
	
	// set language
	this.setLanguage(this.$route)
}

const computed = {
	storageProviderClass() {
		return this.theme + '-storage-provider-' + this.themeVariety
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
	storageProvidersResponse: {
		handler(state, before) {
			this.storageProviders = state.data
			if(this.storageProvider == null && this.storageProviders.length)
				this.selectStorageProvider(this.storageProviders[0].Id)
		},
		deep: true,
		immediate: false
	}
}

const mounted = async function() {
	this.storageProvidersResponse = await this.getStorageProviders()
}

const methods = {
	getStorageProviders(name) {
		const self = this,
			getUri = this.apiProtocol + this.apiHost + ':' +
				this.apiAuthServerPort + this.apiPath + '/storage-providers?name=' +
					((name != undefined) ? name : '')
		return axios(getUri, {
			method: 'get'
		})
	},
	selectStorageProvider(id) {
		this.$emit('storage-provider-changed', id)
	}
}

const destroyed = function() {
}

export default {
	props: [
		'storageProvider'
	],
	mixins: [
		language,
		api
	],
	components: {
	},
	directives: {
	},
	name: 'StorageProvider',
	data () {
		return {
			storageProvidersResponse: null,
			storageProviders: []
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
