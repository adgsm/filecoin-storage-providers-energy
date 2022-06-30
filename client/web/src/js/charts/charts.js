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
		await this.getPowerData()
		await this.getPowerGenerationEnergyConsumptionData()
	},
	async getPowerData() {
		const names = Object.keys(this.hardwareSelections.hardware).join(",")
		const miners = this.hardwareSelections.miners.join(",")
		const from = '2022-06-01T00:00:00.000Z'
		const to = '2022-06-17T00:00:00.000Z'

		let apidata = await this.getChartData('power', this.storageProvider, names, null, miners, null, null, from, to)
		const seriesSplitObj = this.groupObjectsArrayByProperty(apidata, 'Name')
		const seriesNames = Object.keys(seriesSplitObj)
		let series = []
		for (const seria of seriesNames) {
			const data = seriesSplitObj[seria].map((s) => {
				return [new Date(moment(s.Time).format('YYYY-MM-DD HH:mm Z')), s.Power]
			})
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

		this.drawTimeChart('power-chart', this.$t('message.charts.power-chart'), series, seriesNames, [97, 100])
	},
	async getPowerGenerationEnergyConsumptionData() {
		const names = 'Solar pannels'
		const from = '2022-06-01T00:00:00.000Z'
		const to = '2022-06-17T00:00:00.000Z'

		let apidata = await this.getChartData('power', this.storageProvider, names, null, null, null, null, from, to)
		let series = []
		const data = apidata.map((s) => {
			return [new Date(moment(s.Time).format('YYYY-MM-DD HH:mm Z')), s.Power]
		})
		series.push({
			stack: 'Total',
			sampling: 'lttb',
			name: names,
			type: 'line',
			symbol: 'none',
			areaStyle: {},
			data: data
		})

		this.drawTimeChart('solar-power-energy-grid-chart', this.$t('message.charts.solar-power-energy-grid-chart'),
			series, [names], [80, 100])
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
	drawTimeChart(id, title, seriesData, legend, initialZoom) {
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
					start: initialZoom[0],
					end: initialZoom[1]
				},
				{
					start: initialZoom[0],
					end: initialZoom[1]
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
					type: 'time',
					boundaryGap: false
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

		if(this.charts[id] != null) {
			this.charts[id].dispose()
			this.charts[id] = null
		}

		this.charts[id] = ECharts.init(document.getElementById(id), null, {width: 'auto', height: 'auto'})
		this.charts[id].setOption(option, true)
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
			charts: {}
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
