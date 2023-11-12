"use strict";
"require baseclass";
return baseclass.extend({
  title: _("Firewall"),
  rrdargs: function (graph, host, plugin, plugin_instance, dtype) {
    return [
      {
        title: "Firewall: %pi dropped packets",
        rrdopts: ["-u 1"],
        vlabel: "packets/s",
        left_ais_format: "%6.2lf",
        number_format: "%6.2lf",
        totals_format: "%6.2lf",
        data: {
          types: ["flood_packets", "syn_packets", "wan_packets"],
          options: {
            flood_packets: {
              title: "excess SYN rate/s:",
              overlay: false,
              noarea: false,
              color: "ff0000",
              transform_rpn: "1,*",
            },
            syn_packets: {
              title: "rate-limited rate/s:",
              overlay: false,
              noarea: false,
              color: "0000ff",
              transform_rpn: "1,*",
            },
            wan_packets: {
              title: "other wan-in rate/s:",
              overlay: false,
              noarea: false,
              color: "00ff00",
              transform_rpn: "1,*",
            },
          },
        },
      },
    ];
  },
});
