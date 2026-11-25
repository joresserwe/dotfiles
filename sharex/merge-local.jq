["MainFormPosition", "MainFormSize", "ScreenRecordRegion", "MagnifierPixelCount"] as $keys
| $live[0] as $l
| reduce ($l | paths(scalars) | select(.[-1] | IN($keys[]))) as $p (.;
    if (getpath($p[:-1]) | type) == "object" then setpath($p; $l | getpath($p)) else . end)
