clc
clear all
close all

%Inputted Data (RW Signals and Addresses)
[RW,MemAddr_Decimal] = readvars('random4k.txt');
[memrows,memcols] = size(MemAddr_Decimal);

%Specifications
offsetbitwidth = 2; %Constant

%Run All Combinations
for log2associativity = 0:4 
    for rowbitwidth = 1:12 %Ranges from 1 to 12
        for blockbitwidth = 0:4 %Ranges from 0 to 4
            
            %For Testing a Singular Case
            %log2associativity = 0;
            %rowbitwidth = 8;
            %blockbitwidth = 4;
            
            tagbitwidth = 32 - (offsetbitwidth + blockbitwidth + rowbitwidth);
            associativity = (2^log2associativity); %Allowable Values are 1,2,4,8,16

            %Performance Calculation
            SRAMbits = (2^rowbitwidth)*(tagbitwidth+2+((2^blockbitwidth)*32))*(associativity);
            hitRcycles = (1+(rowbitwidth/2)+log2(associativity));
            hitWcycles = (1+(rowbitwidth/2)+log2(associativity));
            missRcycles = (20+(2^blockbitwidth));
            missWcycles = (1+(rowbitwidth/2)+log2(associativity));
            missWBcycles = (1+(2^blockbitwidth));
            hitsR = 0;
            hitsW = 0;
            missesR = 0;
            missesW = 0;
            writebacks = 0;

            %Cache Array Initialization
            cachearray = zeros((2^rowbitwidth),((2^blockbitwidth)+4)*associativity);
            [cacherows,cachecols] = size(cachearray);

            %|Valid|Tag|Frequency|Dirty|Data|
            % 0 for Invalid, 1 for Valid
            % 0 for Clean, 1 for Dirty

            %Program
            for i = 1:memrows
                
                %Bit Parsing
                offset_shift = bitsra(MemAddr_Decimal(i),0);
                offsetbits = bitand(floor(offset_shift),((2^offsetbitwidth)-1));
                block_shift = bitsra(MemAddr_Decimal(i),offsetbitwidth);
                blockbits = bitand(floor(block_shift),((2^blockbitwidth)-1));
                row_shift = bitsra(MemAddr_Decimal(i),(offsetbitwidth+blockbitwidth));
                rowbits = bitand(floor(row_shift),((2^rowbitwidth)-1))+1;
                tag_shift = bitsra(MemAddr_Decimal(i),(offsetbitwidth+blockbitwidth+rowbitwidth));
                tagbits =  bitand(floor(tag_shift),((2^tagbitwidth)-1));

                %Cache Manipulation
                for j = 1:associativity
                    if (cachearray(rowbits,(j+(associativity*0))) == 0) %Is Valid Flag is FALSE?
                        %Miss
                        cachearray(rowbits,(j+(associativity*0))) = 1; %Set Valid Flag to TRUE
                        cachearray(rowbits,(j+(associativity*1))) = tagbits; %Adjust Tagbits
                        cachearray(rowbits,(j+(associativity*2))) = i; %Adjust Frequency
                        if (cell2mat(RW(i)) == 'W')
                            missesW = missesW + 1;
                            cachearray(rowbits,(j+(associativity*3))) = 1; %Set Dirty Bit to DIRTY
                        else
                            missesR = missesR + 1;
                        end
                        break
                    elseif (cachearray(rowbits,(j+(associativity*0))) == 1) %Is Valid Flag is TRUE?
                        if (cachearray(rowbits,(j+(associativity*1))) == tagbits) %Is the Tag Correct?
                            %Hit
                            cachearray(rowbits,(j+(associativity*2))) = i; %Adjust Frequency
                            if (cell2mat(RW(i)) == 'W')
                                cachearray(rowbits,(j+(associativity*3))) = 1; %Set Dirty Bit to DIRTY
                                hitsW = hitsW + 1;
                            else
                                hitsR = hitsR + 1;
                            end
                            break
                        elseif (j == associativity) %Entire Row Has Been Searched 
                              if (cachearray(rowbits,1:associativity) == 1) %All Valid Flags are True
                                %Find LRU
                                for k = 1:associativity
                                   freqarray(k) = cachearray(rowbits,k+(associativity*2)); %Create New Array of Frequency Values
                                end
                                [minval,minind] = min(freqarray); %Find Minimum Value and Minimum Index
                                %Edit LRU Entry
                                if (cachearray(rowbits,(minind+(associativity*3))) == 1) %If Dirty Bit is DIRTY
                                    writebacks = writebacks + 1;
                                end
                                cachearray(rowbits,(minind+(associativity*1))) = tagbits; %Adjust Tagbits
                                cachearray(rowbits,(minind+(associativity*2))) = i; %Adjust Frequency
                                if (cell2mat(RW(i)) == 'W')
                                    missesW = missesW + 1;
                                    cachearray(rowbits,(minind+(associativity*3))) = 1; %Set Dirty Bit to DIRTY
                                else
                                    missesR = missesR + 1;
                                    cachearray(rowbits,(minind+(associativity*3))) = 0; %Set Dirty Bit to DIRTY
                                end
                                break
                              end
                        end
                    end
                end
                
            end

            %Flushing Out Dirty Lines
            for i = 1:cacherows
                for j = 1:associativity
                    if (cachearray(i,(j+(associativity*3))) == 1) %If Dirty Bit is DIRTY
                        writebacks = writebacks + 1;
                        cachearray(i,j) = 0; %Set Valid Flag to TRUE
                        cachearray(i,(j+associativity)) = 0; %Adjust Tagbits
                        cachearray(i,(j+(associativity*2))) = 0; %Reset Frequency
                        cachearray(i,(j+(associativity*3))) = 0; %Set Dirty Flag to CLEAN
                    end
                end
            end

            %Performance Calculation
            totalcycles = (hitsR*hitRcycles)+(hitsW*hitWcycles)+(missesR*missRcycles)+(missesW*missWcycles)+(writebacks*missWBcycles);
            totalhits = hitsR + hitsW;
            totalmisses = missesR + missesW;

            %Displaying Inputs and Outputs
            fprintf('For inputted values of associativity = %d, rowbits = %d, and blockbits = %d, ',associativity,rowbitwidth,blockbitwidth)
            fprintf('we get total cycles = %d, RAM size = %d, hits = %d, misses = %d, and writebacks = %d. \n\n',totalcycles,SRAMbits,totalhits,totalmisses,writebacks)
            
            %format long
            %disp(ceil(totalcycles))
            
        end
    end
end