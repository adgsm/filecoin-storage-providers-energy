import language from '@/src/mixins/i18n/language.js'
import api from '@/src/mixins/api/api.js'

import axios from 'axios'

const created = function() {
	const that = this
	
	// set language
	this.setLanguage(this.$route)
}

const computed = {
	hardwareClass() {
		return this.theme + '-hardware-' + this.themeVariety
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
	async storageProvider(state, before) {
		this.spaces = (await this.getSpaces(state)).data
		console.log(this.spaces)
		for await(const space of this.spaces) {
			this.hardware[space.Space] = (await this.getSpaceHardware(state, space.Space)).data
		}
		console.log(this.hardware)
		this.findHardwareMiners()
		console.log(this.hardwareMiners)
	}
}

const mounted = async function() {
	const scrollContainer = document.querySelector('.' + this.hardwareClass)
	scrollContainer.addEventListener("wheel", (evt) => {
		evt.preventDefault()
		scrollContainer.scrollLeft += evt.deltaY
	})
}

const methods = {
	getSpaces(storageProvider) {
		if(storageProvider == undefined)
			return
		const self = this,
			getUri = this.apiProtocol + this.apiHost + ':' +
				this.apiAuthServerPort + this.apiPath + '/list-spaces?storage_provider_id=' +
					storageProvider
		return axios(getUri, {
			method: 'get'
		})
	},
	getSpaceHardware(storageProvider, space) {
		if(storageProvider == undefined || space == undefined)
			return
		const self = this,
			getUri = this.apiProtocol + this.apiHost + ':' +
				this.apiAuthServerPort + this.apiPath + '/list-space-hardware?storage_provider_id=' +
					storageProvider + '&space=' + space
		return axios(getUri, {
			method: 'get'
		})
	},
	findHardwareMiners() {
		const hardware = Object.keys(this.hardware)
		for (const hw of hardware) {
			console.log(hw, this.hardware[hw])
			for (const rackhw of this.hardware[hw]) {
				if(this.hardwareMiners[hw] == undefined)
					this.hardwareMiners[hw] = []
				if(this.hardwareMiners[hw].indexOf(rackhw.MinerId) == -1)
					this.hardwareMiners[hw].push(rackhw.MinerId)
			}
		}
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
	name: 'Hardware',
	data () {
		return {
			spaces: [],
			hardware: {},
			hardwareMiners: {},
			hardwareExpanded: false
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
