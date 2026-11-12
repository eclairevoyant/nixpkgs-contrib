{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  libsForQt5,
  bison,
  flex,
  eigen,
  boost,
  libGLU,
  libGL,
  glew,
  opencsg,
  cgal_5,
  mpfr,
  gmp,
  glib,
  pkg-config,
  harfbuzz,
  gettext,
  freetype,
  fontconfig,
  double-conversion,
  lib3mf,
  libzip,
  spacenavSupport ? stdenv.hostPlatform.isLinux,
  libspnav,
  wayland,
  wayland-protocols,
  wrapGAppsHook3,
  cairo,
  callPackage,
  runCommand,
  versionCheckHook,
  openscadPackages,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openscad";
  version = "2026.11-RC0";

  src = fetchFromGitHub {
    owner = "openscad";
    repo = "openscad";
    rev = "${finalAttrs.pname}-${finalAttrs.version}";
    hash = "sha256-CO6DSWHveuVpYo99d/imvgTR28VsPnquTQJMgDj+9Qs=";
  };

  nativeBuildInputs = [
    bison
    flex
    pkg-config
    gettext
    libsForQt5.qmake
    libsForQt5.wrapQtAppsHook
    wrapGAppsHook3
  ]
  # versionCheckHook doesn't detect any output on darwin, even though the binary works.
  ++ lib.optional (!stdenv.hostPlatform.isDarwin) versionCheckHook;

  buildInputs = [
    eigen
    boost
    glew
    opencsg
    cgal_5
    mpfr
    gmp
    glib
    harfbuzz
    lib3mf
    libzip
    double-conversion
    freetype
    fontconfig
    libsForQt5.qtbase
    libsForQt5.qtmultimedia
    libsForQt5.qscintilla
    cairo
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    libGLU
    libGL
    wayland
    wayland-protocols
    libsForQt5.qtwayland
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin libsForQt5.qtmacextras
  ++ lib.optional spacenavSupport libspnav;

  qmakeFlags = [
    "VERSION=${finalAttrs.version}"
    "LIB3MF_INCLUDEPATH=${lib3mf.dev}/include/lib3mf/Bindings/Cpp"
    "LIB3MF_LIBPATH=${lib3mf}/lib"
  ]
  ++ lib.optionals spacenavSupport [
    "ENABLE_SPNAV=1"
    "SPNAV_INCLUDEPATH=${libspnav}/include"
    "SPNAV_LIBPATH=${libspnav}/lib"
  ];

  enableParallelBuilding = true;

  preBuild = ''
    make objects/parser.cxx
  '';

  doInstallCheck = true;

  postInstall = lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir $out/Applications
    mv $out/bin/*.app $out/Applications
    ln -s "$out/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" "$out/bin/openscad"

    mv --target-directory=$out/Applications/OpenSCAD.app/Contents/Resources \
      $out/share/openscad/{examples,color-schemes,locale,libraries,fonts,templates}

    rmdir $out/share/openscad
  '';

  meta = {
    description = "3D parametric model compiler";
    longDescription = ''
      OpenSCAD is a software for creating solid 3D CAD objects. It is free
      software and available for Linux/UNIX, MS Windows and macOS.

      Unlike most free software for creating 3D models (such as the famous
      application Blender) it does not focus on the artistic aspects of 3D
      modelling but instead on the CAD aspects. Thus it might be the
      application you are looking for when you are planning to create 3D models of
      machine parts but pretty sure is not what you are looking for when you are more
      interested in creating computer-animated movies.
    '';
    homepage = "https://openscad.org/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [
      bjornfor
      eclairevoyant
      raskin
      xoconoch
    ];
    mainProgram = "openscad";
  };

  passthru = {
    tests = lib.optionalAttrs (!stdenv.hostPlatform.isDarwin) {
      lib3mf_support =
        runCommand "${finalAttrs.pname}-lib3mf-support-test"
          {
            nativeBuildInputs = [ finalAttrs.finalPackage ];
          }
          ''
            echo "cube([1, 1, 1]);" | openscad -o cube.3mf -
            echo "import(\"cube.3mf\");" | openscad -o cube-import.3mf -
            mv cube-import.3mf $out
          '';
    };
    withPackages = callPackage ./wrapper.nix {
      openscad = finalAttrs.finalPackage;
      inherit openscadPackages;
    };
  };
})
