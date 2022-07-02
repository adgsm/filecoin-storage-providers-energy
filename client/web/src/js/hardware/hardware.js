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
			.filter((s) => {return s.Space != 'Data center installation'})
		for await(const space of this.spaces) {
			this.hardware[space.Space] = (await this.getSpaceHardware(state, space.Space)).data
		}
		this.findHardwareMiners()
		this.findMinersHardware()
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
			for (const rackhw of this.hardware[hw]) {
				if(this.hardwareMiners[hw] == undefined)
					this.hardwareMiners[hw] = []
				if(this.hardwareMiners[hw].indexOf(rackhw.MinerId) == -1)
					this.hardwareMiners[hw].push(rackhw.MinerId)
			}
		}
	},
	findMinersHardware() {
		const hardware = Object.keys(this.hardware)
		for (const hw of hardware) {
			for (const rackhw of this.hardware[hw]) {
				if(this.minersHardware[rackhw.MinerId] == undefined)
					this.minersHardware[rackhw.MinerId] = []
				if(this.minersHardware[rackhw.MinerId].indexOf(rackhw.Name) == -1)
					this.minersHardware[rackhw.MinerId].push(rackhw.Name)
			}
		}
	},
	toggleMiner(miner) {
		const index = this.minersSelected.indexOf(miner)
		if(index >  -1)
			this.minersSelected.splice(index, 1)
		else
			this.minersSelected.push(miner)

		this.selectHardwarePerMinersSelection()
	},
	selectHardwarePerMinersSelection() {
		this.hardwareSelected = {}
		for (const miner of this.minersSelected) {
			const minersHardware = this.minersHardware[miner]
			for (const mhw of minersHardware) {
				if(this.hardwareSelected[mhw] == undefined)
				this.hardwareSelected[mhw] = true
			}
		}

		this.announceSelections()
	},
	toggleHardware(hardware) {
		if(this.hardwareSelected[hardware] != undefined)
			delete this.hardwareSelected[hardware]
		else
			this.hardwareSelected[hardware] = true

		this.selectMinersPerHardwareSelection()
	},
	selectMinersPerHardwareSelection() {
		let contains = (arr, target) => target.every(v => arr.includes(v))
		this.minersSelected.length = 0
		const selectedHardware = Object.keys(this.hardwareSelected)
		const miners = Object.keys(this.minersHardware)
		for (const miner of miners) {
			const minersHardware = this.minersHardware[miner]
			const contains = (selectedHardware, minersHardware) => minersHardware.every(v => selectedHardware.includes(v))
			if(contains(selectedHardware, minersHardware))
				this.minersSelected.push(miner)
		}

		this.announceSelections()
	},
	announceSelections() {
		this.$emit('announce-selections', {
			miners: this.minersSelected,
			hardware: this.hardwareSelected
		})
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
			minersHardware: {},
			hardwareSelected: {},
			minersSelected: [],
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
