MathJax.Hub.Config({
  "tex2jax": {
    inlineMath: [['$','$'], ['\\(','\\)']],
    displayMath: [ ['$$','$$'], ['\[','\]'] ]
    processEscapes: true
  }
});
MathJax.Hub.Config({
  config: ["MMLorHTML.js"],
  jax: [
    "input/TeX",
    "output/HTML-CSS",
    "output/NativeMML"
  ],
  extensions: [
    "MathMenu.js",
    "MathZoom.js",
    "TeX/AMSmath.js",
    "TeX/AMSsymbols.js",
    "TeX/autobold.js",
    "TeX/autoload-all.js"
  ]
});
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
// MathJax.Hub.Config({"HTML-CSS": { preferredFont: "TeX", availableFonts: ["STIX","TeX"], linebreaks: { automatic:true }, EqnChunk: (MathJax.Hub.Browser.isMobile ? 10 : 50) },
//         tex2jax: { inlineMath: [ ["\\$", "\\$"], ["\\(", "\\)"] ], displayMath: [ ["$$","$$"], ["\\[", "\\]"] ], processEscapes: true, ignoreClass: "tex2jax_ignore|dno" },
//         TeX: {  noUndefined: { attributes: { mathcolor: "red", mathbackground: "#FFEEEE", mathsize: "90%" } } },
//         messageStyle: "none"
//     });
