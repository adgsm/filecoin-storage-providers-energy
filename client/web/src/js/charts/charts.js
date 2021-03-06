import language from '@/src/mixins/i18n/language.js'

import api from '@/src/mixins/api/api.js'

import axios from 'axios'
import moment from 'moment'

import Button from 'primevue/button'

import Datepicker from '@vuepic/vue-datepicker'

import { markRaw } from 'vue'
import * as ECharts from 'echarts/core'
import {
  TitleComponent,
  ToolboxComponent,
  TooltipComponent,
  GridComponent,
  LegendComponent,
  DataZoomComponent
} from 'echarts/components'
import { LineChart, BarChart } from 'echarts/charts'
import { UniversalTransition } from 'echarts/features'
import { SVGRenderer, CanvasRenderer } from 'echarts/renderers'

ECharts.use([
	TitleComponent,
	ToolboxComponent,
	TooltipComponent,
	GridComponent,
	LegendComponent,
	DataZoomComponent,
	LineChart,
	BarChart,
	CanvasRenderer,
	SVGRenderer,
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
	hardwareSelected() {
		return this.hardwareSelections != undefined &&
			this.hardwareSelections.hardware != undefined &&
			this.hardwareSelections.miners != undefined &&
			Object.keys(this.hardwareSelections.hardware).length
	}
}

const watch = {
	async storageProvider() {
		await this.getPowerGenerationEnergyConsumptionData()
	}
}

const mounted = async function() {
	this.dates = [
		moment().add((-1)*(this.history+1), 'day').toDate(),
		moment().add(-1, 'day').toDate()
	]
}

const methods = {
	async getComponentsPowerData() {
		this.showHardwarePowerChart = true
		await this.getPowerData()
	},
	async getPowerData() {
		if(this.hardwareSelections == null || this.hardwareSelections.hardware == null
			|| this.hardwareSelections.miners == null)
			return

		this.$emit('loading', true)

		const names = Object.keys(this.hardwareSelections.hardware).join(",")
		const miners = this.hardwareSelections.miners.join(",")
		const from = this.dates[0].toISOString()
		const to = this.dates[1].toISOString()
		let series = []

		const apidata = await this.getChartData('power', this.storageProvider, names, null, miners, null, null, from, to)
		const seriesSplitObj = this.groupObjectsArrayByProperty(apidata, 'Name')
		const seriesNames = Object.keys(seriesSplitObj)
		let max = 0
		for (const seria of seriesNames) {
			const data = seriesSplitObj[seria].map((s) => {
				return [new Date(s.Time), s.Power]
			})
			const lmax = Math.max(...data.map((d) => {return d[1]}))
			max += lmax
			series.push({
				stack: 'Total',
				sampling: 'lttb',
				name: seria,
				type: 'line',
				symbol: 'none',
				areaStyle: {},
				data: data,
				tooltip: {
					valueFormatter: function (value) {
						return value + ' W';
					}
				}
			})
		}

		const xAxis = [
			{
				type: 'time',
				boundaryGap: false
			}
		]

		const yAxis = [
			{
				name: 'Power (W)',
				type: 'value',
				boundaryGap: [0, '100%'],
				axisLabel: {
					formatter: '{value} W'
				},
				min: 0,
				max: max,
				interval: Math.floor(max/5)
			}
		]

		this.$emit('loading', false)

		this.drawTimeChart('power-chart', this.$t('message.charts.power-chart'), series, xAxis, yAxis, seriesNames, [97, 100])
	},
	async getPowerGenerationEnergyConsumptionData() {
		const powerNames = 'Solar pannels'
		const energyNames = 'Power grid plug'
		const from = this.dates[0].toISOString()
		const to = this.dates[1].toISOString()
		let series = []
		let powerMin, powerMax, powerRange, powerInterval
		let energyMin, energyMax, energyRange, energyInterval
		let ticksBelowZero

		this.$emit('loading', true)

		const apiPowerData = await this.getChartData('power', this.storageProvider, powerNames, null, null, null, null, from, to)
		const powerData = apiPowerData.map((s) => {
			return [new Date(s.Time), s.Power]
		})
		if(apiPowerData.length > 0) {
			powerMin = Math.floor(Math.min(...powerData.map((d) => {return d[1]})) / 100) * 100
			powerMax = Math.ceil(Math.max(...powerData.map((d) => {return d[1]})) / 100) * 100
		}
		else {
			powerMin = 0
			powerMax = 0
		}

		const apiEnergyData = await this.getChartData('energy', this.storageProvider, energyNames, null, null, null, null, from, to)
		const energyData = apiEnergyData.map((s) => {
			return [new Date(s.Time), s.Energy]
		})
		if(apiEnergyData.length > 0) {
			energyMin = Math.floor(Math.min(...energyData.map((d) => {return d[1]})) / 100) * 100
			energyMax = Math.ceil(Math.max(...energyData.map((d) => {return d[1]})) / 100) * 100
		}
		else {
			energyMin = 0
			energyMax = 0
		}

		if (energyMin > 0)
			energyMin = 0

		energyRange = (energyMin < 0) ? (Math.abs(energyMin) + energyMax) : energyMax
		ticksBelowZero = (energyMin < 0) ? Math.ceil(Math.abs(energyMin)*5/(Math.abs(energyMin) + energyMax)) : 0
		energyInterval = energyRange/5

		if(energyInterval<= 0) {
			energyInterval = null
			powerInterval = null
		}
		else {
			while (energyMax%energyInterval != 0) {
				energyMax += 100
			}
			if (energyMin < 0) {
				while (Math.abs(energyMin)%energyInterval != 0) {
					energyMin -= 100
				}
				ticksBelowZero = Math.abs(energyMin) / energyInterval
			}
	
			energyRange = (energyMin < 0) ? (Math.abs(energyMin) + energyMax) : energyMax
	
			if(powerMin > 0)
				powerMin = 0
	
			powerRange = (powerMin < 0) ? (Math.abs(powerMin) + powerMax) : powerMax
			powerInterval = Math.ceil((powerRange/((energyRange/energyInterval) - ticksBelowZero)) / 100 ) * 100
			powerMin = Math.floor((-1) * ticksBelowZero * powerInterval)
	
			if(powerInterval > 0) {
				while (powerMax%powerInterval != 0) {
					powerMax += 100
				}
				if (powerMin < 0) {
					while (Math.abs(powerMin)%powerInterval != 0) {
						powerMin -= 100
					}
				}
			}
		}

		series.push({
			sampling: 'lttb',
			name: powerNames,
			type: 'line',
			symbol: 'none',
			areaStyle: {},
			data: powerData,
			tooltip: {
				valueFormatter: function (value) {
					return value + ' W';
				}
			}
		},
		{
			sampling: 'lttb',
			name: energyNames,
			type: 'bar',
			symbol: 'none',
			areaStyle: {},
			data: energyData,
			yAxisIndex: 1,
			tooltip: {
				valueFormatter: function (value) {
					return value + ' Wh';
				}
			}
		})

		const xAxis = [
			{
				type: 'time',
				boundaryGap: false,
				axisLine: { onZero: true }
			}
		]

		const yAxis = [
			{
				name: 'Power (W)',
				type: 'value',
				boundaryGap: [0, '100%'],
				axisLabel: {
					formatter: '{value} W'
				},
				alignTicks: true,
				interval : powerInterval,
				max: powerMax,
				min: powerMin
			},
			{
				name: 'Energy (Wh)',
				type: 'value',
				boundaryGap: [0, '100%'],
				oposite: true,
				axisLabel: {
					formatter: '{value} Wh'
				},
				alignTicks: true,
				interval: energyInterval,
				max: energyMax,
				min: energyMin
			}
		]

		this.$emit('loading', false)

		this.drawTimeChart('solar-power-energy-grid-chart', this.$t('message.charts.solar-power-energy-grid-chart'),
			series, xAxis, yAxis, [powerNames, energyNames], [0, 100])
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
	drawTimeChart(id, title, seriesData, xAxis, yAxis, legend, initialZoom) {
		let options = {
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
			xAxis: xAxis,
			yAxis: yAxis,
			series: seriesData
		}

		if(this.charts[id] != null) {
			this.charts[id].dispose()
			this.charts[id] = null
		}

		/*
		You can choose to exit the default depth response / read-only conversion mode, and embed the original,
		unpredictable objects into the state diagram. They can be flexible according to the situation:
		Some values ??????should not be responsive, such as complex third-party class instances or VUE component objects.
		Skip Proxy conversions can improve performance when rendering large numbers with non-variable data sources.
		(https://programmerall.com/article/20052264316/)
		*/
		this.charts[id] = markRaw(ECharts.init(document.getElementById(id), null, {renderer: this.renderer}))
		this.charts[id].setOption(options, true)
	},
	groupObjectsArrayByProperty(arr, property) {
		return arr.reduce(function(memo, x) {
			if (!memo[x[property]]) { memo[x[property]] = []; }
				memo[x[property]].push(x)
				return memo
			}, {}
		)
	},
	async datesChanged(dates) {
		if(dates == null)
			return
		const back = [this.dates[0], this.dates[1]]
		if(dates[0] == null || dates[1] == null) {
			this.dates = back
			return
		}

		if(this.showHardwarePowerChart)
			await this.getPowerData()
		await this.getPowerGenerationEnergyConsumptionData()
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
			showHardwarePowerChart: false,
			maxResults: 1000000,
			charts: {},
			dates: [],
			history: 7,	// 7 days
			renderer: 'canvas'	// svg or canvas
		}
	},
	created: created,
	computed: computed,
	watch: watch,
	mounted: mounted,
	methods: methods,
	destroyed: destroyed
}
