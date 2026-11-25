ObjC.import('AppKit');

const SCALE = 2;
const HEIGHT = 22;
const GAP = 8;
const WIDEST_VALUE = '100%';
const DIMMED_ALPHA = 0.5;
const CAPTION = { size: 7, rect: { y: 13, height: 9 } };
const VALUE = { size: 12, rect: { y: 0, height: 14 } };

function attributes(size, weight, alpha) {
  return $({
    NSFont: $.NSFont.systemFontOfSizeWeight(size, weight),
    NSColor: $.NSColor.blackColor.colorWithAlphaComponent(alpha),
  });
}

function textWidth(text, style) {
  return $(text).sizeWithAttributes(style).width;
}

function pairs(values) {
  const blocks = [];
  for (let index = 0; index + 1 < values.length; index += 2) {
    blocks.push({ caption: values[index], value: values[index + 1] });
  }
  return blocks;
}

function bitmap(width) {
  const rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
    null, width * SCALE, HEIGHT * SCALE, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0
  );
  rep.size = $.NSMakeSize(width, HEIGHT);
  return rep;
}

function drawText(text, x, width, placement, style) {
  $(text).drawWithRectOptionsAttributes(
    $.NSMakeRect(x, placement.rect.y, width, placement.rect.height),
    $.NSStringDrawingUsesLineFragmentOrigin,
    style
  );
}

function run(argv) {
  const alpha = argv[0] === 'dimmed' ? DIMMED_ALPHA : 1;
  const captionStyle = attributes(CAPTION.size, $.NSFontWeightLight, alpha);
  const valueStyle = attributes(VALUE.size, $.NSFontWeightRegular, alpha);
  const blocks = pairs(argv.slice(1));
  blocks.forEach(block => {
    block.width = Math.ceil(Math.max(textWidth(block.caption, captionStyle), textWidth(WIDEST_VALUE, valueStyle)));
  });
  const width = blocks.reduce((sum, block) => sum + block.width, 0) + GAP * (blocks.length - 1);
  const rep = bitmap(width);

  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));
  let x = 0;
  blocks.forEach(block => {
    drawText(block.caption, x, block.width, CAPTION, captionStyle);
    drawText(block.value, x, block.width, VALUE, valueStyle);
    x += block.width + GAP;
  });
  $.NSGraphicsContext.restoreGraphicsState;

  return rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $({})).base64EncodedStringWithOptions(0).js;
}
