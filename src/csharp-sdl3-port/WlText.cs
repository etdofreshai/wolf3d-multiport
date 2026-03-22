// WL_TEXT.C -> WlText.cs
// Text screens - help, end text, ordering info
// Implements ^P/^E/^C/^G/^L/^T/^B markup parsing for text layout

using System;

namespace Wolf3D
{
    public static class WlText
    {
        // Layout constants
        private const int BACKCOLOR = 0x11;
        private const int WORDLIMIT = 80;
        private const int FONTHEIGHT = 10;
        private const int TOPMARGIN = 16;
        private const int BOTTOMMARGIN = 32;
        private const int LEFTMARGIN = 16;
        private const int RIGHTMARGIN = 16;
        private const int PICMARGIN = 8;
        private const int TEXTROWS = ((200 - TOPMARGIN - BOTTOMMARGIN) / FONTHEIGHT);
        private const int SPACEWIDTH = 7;
        private const int SCREENPIXWIDTH = 320;
        private const int SCREENMID = (SCREENPIXWIDTH / 2);

        // Layout state
        private static int pagenum, numpages;
        private static int[] leftmargin = new int[TEXTROWS];
        private static int[] rightmargin = new int[TEXTROWS];
        private static string text;
        private static int textPos;
        private static int rowon;
        private static int picx, picy, picnum, picdelay;
        private static bool layoutdone;

        // =========================================================================
        //  Text parsing helpers
        // =========================================================================

        private static void RipToEOL()
        {
            while (textPos < text.Length && text[textPos] != '\n')
                textPos++;
            if (textPos < text.Length) textPos++; // skip the newline
        }

        private static int ParseNumber()
        {
            // Skip until a number is found
            while (textPos < text.Length && (text[textPos] < '0' || text[textPos] > '9'))
                textPos++;

            string num = "";
            while (textPos < text.Length && text[textPos] >= '0' && text[textPos] <= '9')
            {
                num += text[textPos];
                textPos++;
            }

            if (num.Length == 0) return 0;
            int.TryParse(num, out int result);
            return result;
        }

        private static void ParsePicCommand()
        {
            picy = ParseNumber();
            picx = ParseNumber();
            picnum = ParseNumber();
            RipToEOL();
        }

        private static void ParseTimedCommand()
        {
            picy = ParseNumber();
            picx = ParseNumber();
            picnum = ParseNumber();
            picdelay = ParseNumber();
            RipToEOL();
        }

        private static void TimedPicCommand()
        {
            ParseTimedCommand();
            IdVl.VL_UpdateScreen();

            // Wait for time delay
            int startTime = WL_Globals.TimeCount;
            while (WL_Globals.TimeCount - startTime < picdelay)
            {
                IdSd.SD_TimeCountUpdate();
                SDL.SDL_Delay(1);
            }

            IdVh.VWB_DrawPic(picx & ~7, picy, picnum);
        }

        // =========================================================================
        //  HandleCommand - process ^ commands in text
        // =========================================================================

        private static void HandleCommand()
        {
            textPos++; // skip the '^'
            if (textPos >= text.Length) return;

            char cmd = char.ToUpper(text[textPos]);
            textPos++;

            switch (cmd)
            {
                case 'B': // ^Byyy,xxx,www,hhh - draw bar
                    picy = ParseNumber();
                    picx = ParseNumber();
                    int picwidth_b = ParseNumber();
                    int picheight_b = ParseNumber();
                    IdVh.VWB_Bar(picx, picy, picwidth_b, picheight_b, BACKCOLOR);
                    RipToEOL();
                    break;

                case ';': // comment
                    RipToEOL();
                    break;

                case 'P': // start of next page
                case 'E': // end of file
                    layoutdone = true;
                    textPos -= 2; // back up to the '^'
                    break;

                case 'C': // ^Cxx changes text color (two hex digits)
                    if (textPos < text.Length)
                    {
                        int color = 0;
                        char c1 = char.ToUpper(text[textPos]);
                        textPos++;
                        if (c1 >= '0' && c1 <= '9') color = c1 - '0';
                        else if (c1 >= 'A' && c1 <= 'F') color = c1 - 'A' + 10;
                        color *= 16;
                        if (textPos < text.Length)
                        {
                            char c2 = char.ToUpper(text[textPos]);
                            textPos++;
                            if (c2 >= '0' && c2 <= '9') color += c2 - '0';
                            else if (c2 >= 'A' && c2 <= 'F') color += c2 - 'A' + 10;
                        }
                        WL_Globals.fontcolor = (byte)color;
                    }
                    break;

                case '>': // move to center
                    WL_Globals.px = 160;
                    break;

                case 'L': // ^Lyyy,xxx - locate to specific spot
                    WL_Globals.py = (ushort)ParseNumber();
                    rowon = (WL_Globals.py - TOPMARGIN) / FONTHEIGHT;
                    WL_Globals.py = (ushort)(TOPMARGIN + rowon * FONTHEIGHT);
                    WL_Globals.px = (ushort)ParseNumber();
                    RipToEOL();
                    break;

                case 'T': // ^Tyyy,xxx,ppp,ttt - timed draw graphic
                    TimedPicCommand();
                    break;

                case 'G': // ^Gyyy,xxx,ppp - draw graphic
                    ParsePicCommand();
                    IdVh.VWB_DrawPic(picx & ~7, picy, picnum);
                    // Adjust margins around the picture
                    if (WL_Globals.pictable != null && picnum >= GfxConstants.STARTPICS &&
                        picnum - GfxConstants.STARTPICS < WL_Globals.pictable.Length)
                    {
                        int pw = WL_Globals.pictable[picnum - GfxConstants.STARTPICS].width;
                        int ph = WL_Globals.pictable[picnum - GfxConstants.STARTPICS].height;
                        int picmid = picx + pw / 2;
                        int margin;
                        if (picmid > SCREENMID)
                            margin = picx - PICMARGIN;
                        else
                            margin = picx + pw + PICMARGIN;

                        int top = (picy - TOPMARGIN) / FONTHEIGHT;
                        if (top < 0) top = 0;
                        int bottom = (picy + ph - TOPMARGIN) / FONTHEIGHT;
                        if (bottom >= TEXTROWS) bottom = TEXTROWS - 1;

                        for (int i = top; i <= bottom; i++)
                        {
                            if (picmid > SCREENMID)
                                rightmargin[i] = margin;
                            else
                                leftmargin[i] = margin;
                        }
                        if (WL_Globals.px < leftmargin[rowon])
                            WL_Globals.px = (ushort)leftmargin[rowon];
                    }
                    break;
            }
        }

        // =========================================================================
        //  NewLine
        // =========================================================================

        private static void NewLine()
        {
            rowon++;
            if (rowon >= TEXTROWS)
            {
                layoutdone = true;
                // Skip until next page break
                while (textPos < text.Length)
                {
                    if (text[textPos] == '^' && textPos + 1 < text.Length)
                    {
                        char ch = char.ToUpper(text[textPos + 1]);
                        if (ch == 'E' || ch == 'P')
                        {
                            layoutdone = true;
                            return;
                        }
                    }
                    textPos++;
                }
                return;
            }
            WL_Globals.px = (ushort)leftmargin[rowon];
            WL_Globals.py += FONTHEIGHT;
        }

        // =========================================================================
        //  HandleCtrls
        // =========================================================================

        private static void HandleCtrls()
        {
            char ch = text[textPos++];
            if (ch == '\n')
                NewLine();
        }

        // =========================================================================
        //  HandleWord
        // =========================================================================

        private static void HandleWord()
        {
            string word = "";
            word += text[textPos++];
            while (textPos < text.Length && text[textPos] > 32 && word.Length < WORDLIMIT)
            {
                word += text[textPos++];
            }

            // Measure the word
            int wwidth = 0, wheight = 0;
            IdVh.VW_MeasurePropString(word, out wwidth, out wheight);

            // Check if it fits on this line
            while (WL_Globals.px + wwidth > rightmargin[rowon])
            {
                NewLine();
                if (layoutdone) return;
            }

            // Print it
            int newpos = WL_Globals.px + wwidth;
            WL_Globals.px = (ushort)WL_Globals.px;
            WL_Globals.py = (ushort)WL_Globals.py;
            IdVh.VWB_DrawPropString(word);
            WL_Globals.px = (ushort)newpos;

            // Suck up extra spaces
            while (textPos < text.Length && text[textPos] == ' ')
            {
                WL_Globals.px += SPACEWIDTH;
                textPos++;
            }
        }

        // =========================================================================
        //  PageLayout - clear screen, draw pics, word wrap text
        // =========================================================================

        private static void PageLayout(bool shownumber)
        {
            int oldfontcolor = WL_Globals.fontcolor;
            WL_Globals.fontcolor = (byte)0;

            // Clear the screen with article frame
            IdVh.VWB_Bar(0, 0, 320, 200, BACKCOLOR);
            IdVh.VWB_DrawPic(0, 0, (int)graphicnums.H_TOPWINDOWPIC);
            IdVh.VWB_DrawPic(0, 8, (int)graphicnums.H_LEFTWINDOWPIC);
            IdVh.VWB_DrawPic(312, 8, (int)graphicnums.H_RIGHTWINDOWPIC);
            IdVh.VWB_DrawPic(8, 176, (int)graphicnums.H_BOTTOMINFOPIC);

            for (int i = 0; i < TEXTROWS; i++)
            {
                leftmargin[i] = LEFTMARGIN;
                rightmargin[i] = SCREENPIXWIDTH - RIGHTMARGIN;
            }

            WL_Globals.px = LEFTMARGIN;
            WL_Globals.py = TOPMARGIN;
            rowon = 0;
            layoutdone = false;

            // Make sure we are starting layout text (^P first command)
            while (textPos < text.Length && text[textPos] <= 32)
                textPos++;

            if (textPos < text.Length && text[textPos] == '^')
            {
                textPos++;
                if (textPos < text.Length && char.ToUpper(text[textPos]) == 'P')
                {
                    textPos++;
                    // Skip to end of line
                    while (textPos < text.Length && text[textPos] != '\n')
                        textPos++;
                    if (textPos < text.Length) textPos++;
                }
            }

            // Process text stream
            while (!layoutdone && textPos < text.Length)
            {
                char ch = text[textPos];

                if (ch == '^')
                    HandleCommand();
                else if (ch == '\t')
                {
                    WL_Globals.px = (ushort)((WL_Globals.px + 8) & 0xFFF8);
                    textPos++;
                }
                else if (ch <= 32)
                    HandleCtrls();
                else
                    HandleWord();
            }

            pagenum++;

            if (shownumber)
            {
                string str = "pg " + pagenum.ToString() + " of " + numpages.ToString();
                WL_Globals.py = 183;
                WL_Globals.px = 213;
                WL_Globals.fontcolor = (byte)0x4f;
                IdVh.VWB_DrawPropString(str);
            }

            WL_Globals.fontcolor = (byte)oldfontcolor;
        }

        // =========================================================================
        //  BackPage - scan for previous ^P
        // =========================================================================

        private static void BackPage()
        {
            pagenum--;
            textPos--;
            while (textPos > 0)
            {
                textPos--;
                if (text[textPos] == '^' && textPos + 1 < text.Length &&
                    char.ToUpper(text[textPos + 1]) == 'P')
                    return;
            }
        }

        // =========================================================================
        //  CacheLayoutGraphics - scan article marking used graphics
        // =========================================================================

        private static void CacheLayoutGraphics()
        {
            int savedPos = textPos;
            numpages = 0;
            pagenum = 0;

            while (textPos < text.Length)
            {
                if (text[textPos] == '^' && textPos + 1 < text.Length)
                {
                    char ch = char.ToUpper(text[textPos + 1]);
                    if (ch == 'P')
                        numpages++;
                    else if (ch == 'E')
                    {
                        // End of file, cache the frame graphics
                        IdCa.CA_CacheGrChunk((int)graphicnums.H_TOPWINDOWPIC);
                        IdCa.CA_CacheGrChunk((int)graphicnums.H_LEFTWINDOWPIC);
                        IdCa.CA_CacheGrChunk((int)graphicnums.H_RIGHTWINDOWPIC);
                        IdCa.CA_CacheGrChunk((int)graphicnums.H_BOTTOMINFOPIC);
                        textPos = savedPos;
                        return;
                    }
                    else if (ch == 'G')
                    {
                        textPos += 2;
                        ParsePicCommand();
                        IdCa.CA_CacheGrChunk(picnum);
                        continue;
                    }
                    else if (ch == 'T')
                    {
                        textPos += 2;
                        ParseTimedCommand();
                        IdCa.CA_CacheGrChunk(picnum);
                        continue;
                    }
                }
                textPos++;
            }

            textPos = savedPos;
        }

        // =========================================================================
        //  ShowArticle - display a text article with page navigation
        // =========================================================================

        private static void ShowArticle(string article)
        {
            text = article;
            textPos = 0;

            int oldfontnumber = WL_Globals.fontnumber;
            WL_Globals.fontnumber = 0;

            IdCa.CA_CacheGrChunk(GfxConstants.STARTFONT);
            IdVh.VWB_Bar(0, 0, 320, 200, BACKCOLOR);
            CacheLayoutGraphics();

            bool newpage = true;
            bool firstpage = true;

            do
            {
                if (newpage)
                {
                    newpage = false;
                    PageLayout(true);
                    IdVl.VL_UpdateScreen();
                    if (firstpage)
                    {
                        IdVl.VL_FadeIn();
                        firstpage = false;
                    }
                }

                WL_Globals.LastScan = ScanCodes.sc_None;
                while (WL_Globals.LastScan == ScanCodes.sc_None)
                {
                    IdIn.IN_ProcessEvents();
                    SDL.SDL_Delay(5);
                }

                switch (WL_Globals.LastScan)
                {
                    case ScanCodes.sc_UpArrow:
                    case ScanCodes.sc_PgUp:
                    case ScanCodes.sc_LeftArrow:
                        if (pagenum > 1)
                        {
                            BackPage();
                            BackPage();
                            newpage = true;
                        }
                        break;

                    case ScanCodes.sc_Return:
                    case ScanCodes.sc_DownArrow:
                    case ScanCodes.sc_PgDn:
                    case ScanCodes.sc_RightArrow:
                        if (pagenum < numpages)
                            newpage = true;
                        break;
                }

            } while (WL_Globals.LastScan != ScanCodes.sc_Escape);

            IdIn.IN_ClearKeysDown();
            WL_Globals.fontnumber = oldfontnumber;
        }

        // =========================================================================
        //  HelpScreens - show help text article
        // =========================================================================

        public static void HelpScreens()
        {
            // Load the help article from grsegs (T_HELPART)
            int artnum = (int)graphicnums.T_HELPART;
            IdCa.CA_CacheGrChunk(artnum);

            byte[] data = WL_Globals.grsegs[artnum];
            if (data != null && data.Length > 0)
            {
                string article = System.Text.Encoding.ASCII.GetString(data);
                ShowArticle(article);
            }
            else
            {
                // Fallback: display a simple help screen
                IdVh.VWB_Bar(0, 0, 320, 200, BACKCOLOR);
                WL_Globals.fontcolor = (byte)0x0f;
                WL_Globals.fontnumber = 1;
                WL_Globals.px = 80;
                WL_Globals.py = 80;
                IdVh.VW_DrawPropString("Help not available");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
            }

            IdVl.VL_FadeOut();
        }

        // =========================================================================
        //  EndText - show end-game text article for the given episode
        // =========================================================================

        public static void EndText()
        {
            // Load the end article for the current episode
            int episode = WL_Globals.gamestate.episode;
            int artnum = (int)graphicnums.T_ENDART1 + episode;
            if (artnum > (int)graphicnums.T_ENDART6)
                artnum = (int)graphicnums.T_ENDART1;

            IdCa.CA_CacheGrChunk(artnum);

            byte[] data = WL_Globals.grsegs[artnum];
            if (data != null && data.Length > 0)
            {
                string article = System.Text.Encoding.ASCII.GetString(data);
                ShowArticle(article);
            }
            else
            {
                // Fallback
                IdVh.VWB_Bar(0, 0, 320, 200, BACKCOLOR);
                WL_Globals.fontcolor = (byte)0x0f;
                WL_Globals.fontnumber = 1;
                WL_Globals.px = 60;
                WL_Globals.py = 80;
                IdVh.VW_DrawPropString("Congratulations!");
                WL_Globals.px = 60;
                WL_Globals.py = 100;
                IdVh.VW_DrawPropString("You have completed the episode.");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
            }

            IdVl.VL_FadeOut();
        }

        // =========================================================================
        //  OrderingInfo - display ordering information screen
        // =========================================================================

        public static void OrderingInfo()
        {
            IdCa.CA_CacheScreen((int)graphicnums.ORDERSCREEN);
            IdVl.VL_UpdateScreen();
            IdVl.VL_FadeIn();
            IdIn.IN_Ack();
            IdVl.VL_FadeOut();
        }
    }
}
