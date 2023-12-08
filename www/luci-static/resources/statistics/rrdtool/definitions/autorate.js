"use strict";
"require baseclass";
return baseclass.extend({
  title: _("Autorate"),
  rrdargs: function (graph, host, plugin, plugin_instance, dtype) {
    var control = {
      title: "**** Autorate: reflector %pi CONTROL ****",
      rrdopts: ["--logarithmic"],
      vlabel: "units",
      left_ais_format: "%7.0lf",
      number_format: "%7.0lf",
      totals_format: "%7.0lf",
      data: {
        types: ["autorate"],
        sources: { autorate: ["11", "28", "29"] },
        options: {
          autorate__11: { title: "SEQUENCE:", overlay: true, noavg: true, noarea: true },
          autorate__28: { title: "DL BUFFERBLOAT:", overlay: true, noavg: true, noarea: true },
          autorate__29: { title: "UL BUFFERBLOAT:", overlay: true, noavg: true, noarea: true },
        },
      },
    };
    var bandwidth = {
      title: "reflector %pi bandwidth",
      vlabel: "Rate [Mbps]",
      left_ais_format: "%7.0lf",
      number_format: "%7.0lf",
      totals_format: "%7.0lf",
      data: {
        types: ["autorate"],
        sources: { autorate: ["5", "6", "30", "31"] },
        options: {
          autorate__5: { title: "DL_ACHIEVED_RATE_Mbps:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/" },
          autorate__6: { title: "UL_ACHIEVED_RATE_Mbps:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/", flip: true },
          autorate__30: { title: "CAKE_DL_RATE_Mbps:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/" },
          autorate__31: { title: "CAKE_UL_RATE_Mbps:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/", flip: true },
        },
      },
    };
    var latency = {
      title: "reflector %pi latency",
      vlabel: "Delay [milliseconds]",
      y_max: "60",
      y_min: "-60",
      left_ais_format: "%7.0lf",
      number_format: "%7.0lf",
      totals_format: "%7.0lf",
      data: {
        types: ["autorate"],
        sources: { autorate: ["12", "13a", "13", "14", "15", "16", "17", "18a", "18", "19", "20", "21"] },
        options: {
          autorate__12: { title: "DL_OWD_BASELINE:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__13a: { title: "DL_OWD_EWMA_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__13: { title: "DL_OWD_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__14: { title: "DL_OWD_DELTA_EWMA_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/" },
          autorate__15: { title: "DL_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__16: { title: "DL_ADJ_DELAY_THR:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__17: { title: "UL_OWD_BASELINE:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
          autorate__18a: { title: "UL_OWD_EWMA_US:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
          autorate__18: { title: "UL_OWD_US:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
          autorate__19: { title: "UL_OWD_DELTA_EWMA_US:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/" },
          autorate__20: { title: "UL_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
          autorate__21: { title: "UL_ADJ_DELAY_THR:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
        },
      },
    };
    var dl_us = {
      title: "reflector %pi dl latency",
      vlabel: "Delay [milliseconds]",
      y_max: "60000",
      y_min: "0",
      left_ais_format: "%7.0lf",
      number_format: "%7.0lf",
      totals_format: "%7.0lf",
      data: {
        types: ["autorate"],
        sources: { autorate: ["12", "13", "14", "15", "16"] },
        options: {
          autorate__12: { title: "DL_OWD_BASELINE:", overlay: true, noavg: true, noarea: true },
          autorate__13: { title: "DL_OWD_US:", overlay: true, noavg: true, noarea: true },
          autorate__14: { title: "DL_OWD_DELTA_EWMA_US:", overlay: true, noavg: true, noarea: true },
          autorate__15: { title: "DL_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true },
          autorate__16: { title: "DL_ADJ_DELAY_THR:", overlay: true, noavg: true, noarea: true },
        },
      },
    };
    var ul_us = {
      title: "reflector %pi ul latency",
      vlabel: "Delay [milliseconds]",
      y_max: "0",
      y_min: "-60000",
      left_ais_format: "%7.0lf",
      number_format: "%7.0lf",
      totals_format: "%7.0lf",
      data: {
        types: ["autorate"],
        sources: { autorate: ["17", "18", "19", "20", "21"] },
        options: {
          autorate__17: { title: "UL_OWD_BASELINE:", overlay: true, noavg: true, noarea: true, flip: true },
          autorate__18: { title: "UL_OWD_US:", overlay: true, noavg: true, noarea: true, flip: true },
          autorate__19: { title: "UL_OWD_DELTA_EWMA_US:", overlay: true, noavg: true, noarea: true },
          autorate__20: { title: "UL_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true, flip: true },
          autorate__21: { title: "UL_ADJ_DELAY_THR:", overlay: true, noavg: true, noarea: true, flip: true },
        },
      },
    };
    var auto = {
      title: "Autorate: reflector %pi",
      rrdopts: ["--logarithmic"],
      vlabel: "units/s",
      left_ais_format: "%7.0lf",
      number_format: "%7.0lf",
      totals_format: "%7.0lf",
      data: {
        types: ["autorate"],
        sources: { autorate: ["11", "5", "6", "7", "8", "12", "13a", "13", "14", "15", "16", "17", "18a", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31"] },
        options: {
          autorate: { title: "Backlog:", overlay: true, color: "0000ff" },
          autorate__11: { title: "SEQUENCE:", overlay: true, noavg: true, noarea: true },
          autorate__5: { title: "DL_ACHIEVED_RATE_KBPS:", overlay: true, noavg: true, noarea: true },
          autorate__6: { title: "UL_ACHIEVED_RATE_KBPS:", overlay: true, noavg: true, noarea: true },
          autorate__7: { title: "DL_LOAD_PERCENT:", overlay: true, noavg: true, noarea: true },
          autorate__8: { title: "UL_LOAD_PERCENT:", overlay: true, noavg: true, noarea: true },
          autorate__12: { title: "DL_OWD_BASELINE:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__13a: { title: "DL_OWD_EWMA_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__13: { title: "DL_OWD_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__14: { title: "DL_OWD_DELTA_EWMA_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/" },
          autorate__15: { title: "DL_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__16: { title: "DL_ADJ_DELAY_THR:", overlay: true, noavg: true, noarea: true, transform_rpn: "1000,/"  },
          autorate__17: { title: "UL_OWD_BASELINE:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
          autorate__18a: { title: "UL_OWD_EWMA_US:", overlay: true, noavg: true, noarea: true, flip: true, transform_rpn: "1000,/"  },
          autorate__19: { title: "UL_OWD_DELTA_EWMA_US:", overlay: true, noavg: true, noarea: true },
          autorate__20: { title: "UL_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true },
          autorate__21: { title: "UL_ADJ_DELAY_THR:", overlay: true, noavg: true, noarea: true },
          autorate__22: { title: "DL_SUM_DELAYS:", overlay: true, noavg: true, noarea: true },
          autorate__23: { title: "DL_AVG_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true },
          autorate__24: { title: "DL_ADJ_AVG_OWD_DELTA_THR_US:", overlay: true, noavg: true, noarea: true },
          autorate__25: { title: "UL_SUM_DELAYS:", overlay: true, noavg: true, noarea: true },
          autorate__26: { title: "UL_AVG_OWD_DELTA_US:", overlay: true, noavg: true, noarea: true },
          autorate__27: { title: "UL_ADJ_AVG_OWD_DELTA_THR_US:", overlay: true, noavg: true, noarea: true },
          autorate__28: { title: "DL_LOAD_CONDITION:", overlay: true, noavg: true, noarea: true },
          autorate__29: { title: "UL_LOAD_CONDITION:", overlay: true, noavg: true, noarea: true },
          autorate__30: { title: "CAKE_DL_RATE_KBPS:", overlay: true, noavg: true, noarea: true },
          autorate__31: { title: "CAKE_UL_RATE_KBPS:", overlay: true, noavg: true, noarea: true },
        },
      },
    };
    return [control,bandwidth,latency,dl_us,ul_us];
  },
});


