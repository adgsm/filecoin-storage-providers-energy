export default {
	data () {
		const address = window.location.href
		const host = window.location.host.split(':')[0]
		return {
			//api protocol, host and ports definitions
			apiProtocol: (host == 'localhost' || host == '127.0.0.1') ? 'http://' : 'https://',
			apiHost: host,
			apiPath: '/sp-metered-energy/api/v1',
			apiAuthServerPort: (host == 'localhost' || host == '127.0.0.1') ? 3001 : 443
		}
	}
}
