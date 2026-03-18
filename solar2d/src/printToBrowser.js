// Bridge Lua print calls to the browser console in HTML5 builds.
window.printToBrowser = {
	alert: function(msg)
	{
        alert(msg);
	},
	log: function(msg)
	{
        console.log(msg);
	}
}