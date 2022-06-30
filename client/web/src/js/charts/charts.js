import language from '@/src/mixins/i18n/language.js'

import api from '@/src/mixins/api/api.js'

import axios from 'axios'
import moment from 'moment'

import Button from 'primevue/button'

import Datepicker from '@vuepic/vue-datepicker'

import * as ECharts from 'echarts/core'
import {
  TitleComponent,
  ToolboxComponent,
  TooltipComponent,
  GridComponent,
  LegendComponent,
  DataZoomComponent
} from 'echarts/components'
import { LineChart } from 'echarts/charts'
import { UniversalTransition } from 'echarts/features'
import { CanvasRenderer } from 'echarts/renderers'

ECharts.use([
	TitleComponent,
	ToolboxComponent,
	TooltipComponent,
	GridComponent,
	LegendComponent,
	DataZoomComponent,
	LineChart,
	CanvasRenderer,
	UniversalTransition
])

const created = function() {
	const that = this
	
	// set language
	this.setLanguage(this.$route)
}

const computed = {
	chartsClass() {
		return this.theme + '-charts-' + this.themeVariety
	},
	locale() {
		return this.$store.getters['dashboard/getLocale']
	},
	theme() {
		return this.$store.getters['dashboard/getTheme']
	},
	themeVariety() {
		return this.$store.getters['dashboard/getThemeVariety']
	},
	readyToGetData() {
		return this.hardwareSelections != undefined &&
			this.hardwareSelections.hardware != undefined && this.hardwareSelections.miners
	}
}

const watch = {
}

const mounted = async function() {
}

const methods = {
	async getData() {
		const names = Object.keys(this.hardwareSelections.hardware).join(",")
		const miners = this.hardwareSelections.miners.join(",")
		const from = '2022-06-01T00:00:00.000Z'
		const to = '2022-06-17T00:00:00.000Z'

		let data = await this.getChartData('power', this.storageProvider, names, null, miners, null, null, from, to)
		const timeAxisData = data
			.map((r) => {return moment(r.Time).format('YYYY-MM-DD HH:mm Z')})
			.slice().sort(function(a,b){return a > b}).reduce(function(a,b){if (a.slice(-1)[0] !== b) a.push(b);return a;},[])
		const seriesSplitObj = this.groupObjectsArrayByProperty(data, 'Name')
		const seriesNames = Object.keys(seriesSplitObj)
		let series = []
		for (const seria of seriesNames) {
			const data = seriesSplitObj[seria].map((s) => {return s.Power})
			series.push({
				stack: 'Total',
				sampling: 'lttb',
				name: seria,
				type: 'line',
				symbol: 'none',
				areaStyle: {},
				data: data
			})
		}

		this.drawCharts(this.$t('message.charts.power-chart'), timeAxisData, series, seriesNames)
	},
	getChartDataChunk(endPoint, storageProvider, names, locations, miners, racks, functions, from, to, offset, limit) {
		if(endPoint == undefined || storageProvider == undefined || from == undefined || to == undefined)
			return
		if(names == undefined)
			names = ''
		if(locations == undefined)
			locations = ''
		if(miners == undefined)
			miners = ''
		if(racks == undefined)
			racks = ''
		if(functions == undefined)
			functions = ''
		if(offset == undefined)
			offset = 0
		if(limit == undefined)
			limit = this.maxResults
		const self = this,
			getUri = this.apiProtocol + this.apiHost + ':' +
				this.apiAuthServerPort + this.apiPath + '/' + endPoint + '?storage_provider_id=' + storageProvider +
					'&names=' + names + '&locations=' + locations + '&miners=' + miners +
					'&racks=' + racks + '&functions=' + functions + '&from=' + from + '&to=' + to +
					'&offset=' + offset + '&limit=' + limit
console.log(getUri)
		return axios(getUri, {
			method: 'get'
		})
	},
	async getChartData(endPoint, storageProvider, names, locations, miners, racks, functions, from, to) {
		if(endPoint == undefined || storageProvider == undefined || from == undefined || to == undefined)
			return

		if(names == undefined)
			names = ''
		if(locations == undefined)
			locations = ''
		if(miners == undefined)
			miners = ''
		if(racks == undefined)
			racks = ''
		if(functions == undefined)
			functions = ''

		let offset = 0
		let data = []
		let chunkData = []
		let br = false
		do {
			const chunk = await this.getChartDataChunk(endPoint, storageProvider, names, locations, miners,
				racks, functions, from, to, offset, this.maxResults)
			offset += this.maxResults
			chunkData = chunk.data
			data = data.concat(chunkData)
			br = offset > chunkData.length
		} while (chunkData.length && !br)

		return data
	},
	drawCharts(title, timeAxisData, seriesData, legend) {
		let option = {
			title: {
			  text: title
			},
			tooltip: {
			  trigger: 'axis',
			  axisPointer: {
				type: 'cross',
				label: {
				  backgroundColor: '#6a7985'
				}
			  }
			},
			legend: {
			  data: legend
			},
			dataZoom: [
			  {
				type: 'inside',
				start: 97,
				end: 100
			  },
			  {
				start: 97,
				end: 100
			  }
			],
			toolbox: {
			  feature: {
				dataZoom: {
				  yAxisIndex: 'none'
				},
				restore: {},
				saveAsImage: {}
			  }
			},
			xAxis: [
			  {
				type: 'category',
				boundaryGap: false,
				data: timeAxisData
			  }
			],
			yAxis: [
			  {
				type: 'value',
			  boundaryGap: [0, '100%']
			  }
			],
			series: seriesData
		  }

		if(this.charts != null) {
			this.charts.dispose()
			this.charts = null
		}

		this.charts = ECharts.init(document.getElementById('charts'), null, {width: 'auto', height: 'auto'})
		this.charts.setOption(option, true)
	},
	groupObjectsArrayByProperty(arr, property) {
		return arr.reduce(function(memo, x) {
			if (!memo[x[property]]) { memo[x[property]] = []; }
				memo[x[property]].push(x)
				return memo
			}, {}
		)
	}
}

const destroyed = function() {
}

export default {
	props: [
		'storageProvider', 'hardwareSelections'
	],
	mixins: [
		language,
		api
	],
	components: {
		Datepicker,
		Button
	},
	directives: {
	},
	name: 'Charts',
	data () {
		return {
			maxResults: 1000000,
			chart: null
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
