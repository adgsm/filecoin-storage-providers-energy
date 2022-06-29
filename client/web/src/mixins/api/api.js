export default {
	data () {
		const address = window.location.href;
		return {
			//api protocol, host and ports definitions
			apiProtocol: 'http://',
			apiHost: window.location.host.split(':')[0],
			apiPath: '/sp-metered-energy/api/v1',
			apiAuthServerPort: 3001
		}
	}
}
