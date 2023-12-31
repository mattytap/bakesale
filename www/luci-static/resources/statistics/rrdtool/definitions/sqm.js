"use strict";
"require baseclass";
return baseclass.extend({
  title: _("SQM"),
  rrdargs: function (graph, host, plugin, plugin_instance, dtype) {
    var overview = {
      per_instance: false,
      title: "%H: SQM qdisc %pi Overview",
      rrdopts: ["--logarithmic"],
      vlabel: " ",
      alt_autoscale: true,
      number_format: "%5.0lf",
      data: {
        types: ["qdisc_bytes", "qdisc_band", "qdisc_backlog", "qdisc_drops"],
        options: {
          qdisc_bytes: {
            title: "kb/s:",
            overlay: true,
            noarea: false,
            color: "0000ff",
            transform_rpn: "125,/",
          },
          qdisc_band: {
            title: "Bandwidth:",
            overlay: true,
            noarea: true,
            color: "000000",
            transform_rpn: "125,/",
          },
          qdisc_backlog: {
            title: "Backlog/B:",
            overlay: true,
            noarea: true,
            color: "8000ff",
          },
          qdisc_drops: {
            title: "Drops/s:",
            overlay: true,
            noarea: true,
            color: "00ffff",
          },
        },
      },
    };
    return [overview];
  },
});
