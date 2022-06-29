import language from '@/src/mixins/i18n/language.js'

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
		Datepicker
	},
	directives: {
	},
	name: 'Charts',
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
