"use strict";
"require baseclass";
return baseclass.extend({
  title: _("Ping"),
  rrdargs: function (graph, host, plugin, plugin_instance, dtype) {
    var ping = {
      title: "%H: ICMP Round Trip Time",
      vlabel: "ms",
      rrdopts: ["--logarithmic"],
      number_format: "%5.1lf ms",
      data: {
        sources: { ping: ["value"] },
        options: {
          ping__value: {
            noarea: true,
            overlay: true,
            title: "%di",
          },
        },
      },
    };
    var droprate = {
      title: "%H: ICMP Drop Rate",
      vlabel: "%",
      y_min: "0",
      y_max: "4",
      number_format: "%5.2lf %%",
      data: {
        types: ["ping_droprate"],
        options: {
          ping_droprate: {
            noarea: true,
            overlay: true,
            title: "%di",
            transform_rpn: "100,*",
          },
        },
      },
    };
    var stddev = {
      title: "%H: ICMP Standard Deviation",
      vlabel: "ms",
      y_min: "0",
      y_max: "1",
      number_format: "%5.1lf ms",
      data: {
        types: ["ping_stddev"],
        options: {
          ping_stddev: {
            noarea: true,
            overlay: true,
            title: "%di",
          },
        },
      },
    };
    return [ping, droprate, stddev];
  },
});
