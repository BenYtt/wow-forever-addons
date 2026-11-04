local _, FLT = ...

-- Fallback talent layout, used only when the live client talents cannot be
-- matched to TalentData.lua (e.g. a localized client or a build whose talent
-- names changed). It guesses the three trees and the grid positions from the
-- client's node coordinates. With matching reference data this file is unused.

local function splitByGlobalX(all)
  local result={{},{},{}}
  if #all==0 then return result end
  local sorted={}
  for _,n in ipairs(all) do sorted[#sorted+1]=n end
  table.sort(sorted,function(a,b)
    if a.x==b.x then return a.y<b.y end
    return a.x<b.x
  end)
  local minX,maxX=sorted[1].x,sorted[#sorted].x
  local span=math.max(1,maxX-minX)
  for _,n in ipairs(sorted) do
    local norm=(n.x-minX)/span
    local ix=(norm<0.333 and 1) or (norm<0.666 and 2) or 3
    result[ix][#result[ix]+1]=n
  end
  return result
end

local function splitBySubTree(all)
  local buckets,order={},{}
  for _,n in ipairs(all) do
    local sid=n.subTreeID or (n.info and n.info.subTreeID)
    if sid then
      if not buckets[sid] then buckets[sid]={}; order[#order+1]=sid end
      buckets[sid][#buckets[sid]+1]=n
    end
  end
  if #order<3 then return nil end
  table.sort(order,function(a,b) return tostring(a)<tostring(b) end)
  local ranked={}
  for idx,sid in ipairs(order) do ranked[#ranked+1]={sid=sid,nodes=buckets[sid],index=idx} end
  table.sort(ranked,function(a,b) return #a.nodes>#b.nodes end)
  if #ranked<3 or #ranked[3].nodes<2 then return nil end
  local chosen={ranked[1],ranked[2],ranked[3]}
  table.sort(chosen,function(a,b) return a.index<b.index end)
  return {chosen[1].nodes,chosen[2].nodes,chosen[3].nodes}
end

local function averageX(nodes)
  if not nodes or #nodes==0 then return 0 end
  local total=0
  for _,n in ipairs(nodes) do total=total+n.x end
  return total/#nodes
end

local function normalizeSplit(cols)
  local ordered={cols[1] or {}, cols[2] or {}, cols[3] or {}}
  table.sort(ordered,function(a,b) return averageX(a)<averageX(b) end)
  return ordered
end

local function splitByColumnBands(all)
  if #all==0 then return nil end
  local sorted={}
  for _,n in ipairs(all) do sorted[#sorted+1]=n end
  table.sort(sorted,function(a,b)
    if a.x==b.x then return a.y<b.y end
    return a.x<b.x
  end)

  local diffs={}
  for i=2,#sorted do
    local d=sorted[i].x-sorted[i-1].x
    if d>0 then diffs[#diffs+1]=d end
  end
  if #diffs==0 then return nil end
  table.sort(diffs)

  local threshold=diffs[1]*1.75
  local columns={{nodes={sorted[1]}, avgX=sorted[1].x}}
  for i=2,#sorted do
    local n=sorted[i]
    local col=columns[#columns]
    if math.abs(n.x-col.avgX) <= threshold then
      col.nodes[#col.nodes+1]=n
      local total=0
      for _,cn in ipairs(col.nodes) do total=total+cn.x end
      col.avgX=total/#col.nodes
    else
      columns[#columns+1]={nodes={n}, avgX=n.x}
    end
  end

  if #columns < 3 then return nil end
  local colsPerBand=math.max(1, math.ceil(#columns/3))
  local result={{},{},{}}
  for idx,col in ipairs(columns) do
    local band=math.min(3, math.ceil(idx/colsPerBand))
    for _,n in ipairs(col.nodes) do result[band][#result[band]+1]=n end
  end
  return normalizeSplit(result)
end

local function splitByKMeansX(all)
  if #all<3 then return nil end
  local sorted={}
  for _,n in ipairs(all) do sorted[#sorted+1]=n end
  table.sort(sorted,function(a,b) return a.x<b.x end)

  local function pick(frac)
    return sorted[math.max(1, math.min(#sorted, math.floor(#sorted*frac + 0.5)))]
  end
  local centers={pick(0.17).x, pick(0.50).x, pick(0.83).x}
  for _=1,10 do
    local buckets={{},{},{}}
    for _,n in ipairs(sorted) do
      local best,bestDist=1,math.abs(n.x-centers[1])
      for i=2,3 do
        local d=math.abs(n.x-centers[i])
        if d<bestDist then best,bestDist=i,d end
      end
      buckets[best][#buckets[best]+1]=n
    end
    for i=1,3 do
      if #buckets[i]>0 then
        local total=0
        for _,n in ipairs(buckets[i]) do total=total+n.x end
        centers[i]=total/#buckets[i]
      end
    end
  end

  local final={{},{},{}}
  for _,n in ipairs(sorted) do
    local best,bestDist=1,math.abs(n.x-centers[1])
    for i=2,3 do
      local d=math.abs(n.x-centers[i])
      if d<bestDist then best,bestDist=i,d end
    end
    final[best][#final[best]+1]=n
  end
  return normalizeSplit(final)
end

local function splitQuality(cols)
  if not cols then return -999999 end
  local a,b,c=#(cols[1] or {}), #(cols[2] or {}), #(cols[3] or {})
  local minc=math.min(a,b,c)
  local maxc=math.max(a,b,c)
  local total=a+b+c
  local avg=(total>0) and (total/3) or 0
  local deviation=math.abs(a-avg)+math.abs(b-avg)+math.abs(c-avg)
  local zeroPenalty=((a==0) and 40 or 0)+((b==0) and 40 or 0)+((c==0) and 40 or 0)
  local tinyPenalty=((a<2) and 10 or 0)+((b<2) and 10 or 0)+((c<2) and 10 or 0)
  return (minc*100) - ((maxc-minc)*4) - deviation - zeroPenalty - tinyPenalty
end


local function normalizedTreeName(name)
  name=string.lower(name or "")
  name=name:gsub("magic","")
  name=name:gsub("combat","")
  name=name:gsub("[^a-z]","")
  return name
end

local function splitByNamedSubTrees(configID, all, class)
  if not (C_Traits and C_Traits.GetSubTreeInfo) then return nil end

  local sidNodes={}
  for _,n in ipairs(all) do
    local sid=n.subTreeID or (n.info and n.info.subTreeID)
    if sid then
      sidNodes[sid]=sidNodes[sid] or {}
      sidNodes[sid][#sidNodes[sid]+1]=n
    end
  end

  local subtrees={}
  for sid,nodes in pairs(sidNodes) do
    local ok,info=pcall(C_Traits.GetSubTreeInfo,configID,sid)
    if ok and info then
      subtrees[#subtrees+1]={sid=sid,nodes=nodes,info=info,name=info.name or "",x=info.posX or averageX(nodes)}
    end
  end
  if #subtrees<3 then return nil end

  local result={{},{},{}}
  local used={}
  local targets={}
  for i=1,3 do targets[i]=normalizedTreeName(class.trees[i]) end

  -- First use the client-provided subtree names. This is the authoritative
  -- specialization split and avoids Hunter's shared/global coordinates.
  for _,st in ipairs(subtrees) do
    local sn=normalizedTreeName(st.name)
    for i=1,3 do
      if not used[i] and sn~="" and (sn==targets[i] or sn:find(targets[i],1,true) or targets[i]:find(sn,1,true)) then
        result[i]=st.nodes; used[i]=st; break
      end
    end
  end

  -- Some Forever builds omit/localize subtree names. Fill any missing tree by
  -- the subtree's real client X center, left-to-right, instead of NodeID order.
  local remaining={}
  for _,st in ipairs(subtrees) do
    local already=false
    for i=1,3 do if used[i]==st then already=true; break end end
    if not already and #st.nodes>=2 then remaining[#remaining+1]=st end
  end
  table.sort(remaining,function(a,b) return (a.x or 0)<(b.x or 0) end)
  local ri=1
  for i=1,3 do
    if #result[i]==0 and remaining[ri] then
      result[i]=remaining[ri].nodes; used[i]=remaining[ri]; ri=ri+1
    end
  end

  -- Nodes without a subtree ID are rare shared/changed nodes. Attach them to
  -- the nearest resolved subtree center so they remain in the correct panel.
  for _,n in ipairs(all) do
    local sid=n.subTreeID or (n.info and n.info.subTreeID)
    if not sid then
      local best,bestDist=nil,nil
      for i=1,3 do
        local st=used[i]
        if st then
          local cx=st.x or averageX(result[i])
          local d=math.abs((n.x or 0)-cx)
          if not bestDist or d<bestDist then best,bestDist=i,d end
        end
      end
      if best then result[best][#result[best]+1]=n end
    end
  end

  if #result[1]>=5 and #result[2]>=5 and #result[3]>=5 then return result end
  return nil
end

local function splitIntoThree(groups, all, class, configID)
  local named=splitByNamedSubTrees(configID,all,class)
  if named then return named end

  local candidates={}
  if #groups==3 then
    candidates[#candidates+1]=normalizeSplit({groups[1].nodes,groups[2].nodes,groups[3].nodes})
  elseif #groups>3 then
    local ranked={}
    for idx,g in ipairs(groups) do ranked[#ranked+1]={index=idx,nodes=g.nodes} end
    table.sort(ranked,function(a,b) return #a.nodes>#b.nodes end)
    if #ranked>=3 then
      local chosen={ranked[1],ranked[2],ranked[3]}
      table.sort(chosen,function(a,b) return averageX(a.nodes)<averageX(b.nodes) end)
      candidates[#candidates+1]={chosen[1].nodes,chosen[2].nodes,chosen[3].nodes}
    end
  end

  local bySubTree=splitBySubTree(all)
  if bySubTree then candidates[#candidates+1]=normalizeSplit(bySubTree) end

  local byBands=splitByColumnBands(all)
  if byBands then candidates[#candidates+1]=byBands end

  local byGlobal=splitByGlobalX(all)
  if byGlobal then candidates[#candidates+1]=normalizeSplit(byGlobal) end

  local byKMeans=splitByKMeansX(all)
  if byKMeans then candidates[#candidates+1]=byKMeans end

  local best,bestScore=nil,-999999
  for _,cand in ipairs(candidates) do
    local score=splitQuality(cand)
    if score>bestScore then best,bestScore=cand,score end
  end
  return best or {{},{},{}}
end

local function assignGrid(nodes)
  local placed={}
  if #nodes==0 then return placed end
  local minX,maxX,minY,maxY=nodes[1].x,nodes[1].x,nodes[1].y,nodes[1].y
  for _,n in ipairs(nodes) do
    minX=math.min(minX,n.x); maxX=math.max(maxX,n.x)
    minY=math.min(minY,n.y); maxY=math.max(maxY,n.y)
  end
  local sx=math.max(1,maxX-minX)
  local sy=math.max(1,maxY-minY)
  local ordered={}
  for _,n in ipairs(nodes) do ordered[#ordered+1]=n end
  table.sort(ordered,function(a,b)
    if a.y==b.y then return a.x<b.x end
    return a.y<b.y
  end)
  local used={}
  local function key(c,r) return c..":"..r end
  for _,n in ipairs(ordered) do
    local col=math.floor(((n.x-minX)/sx)*3+0.5)+1
    local row=math.floor(((n.y-minY)/sy)*6+0.5)+1
    col=math.max(1,math.min(4,col)); row=math.max(1,math.min(7,row))
    if used[key(col,row)] then
      local found
      for radius=1,3 do
        for _,dc in ipairs({-radius,radius}) do
          local c=col+dc
          if c>=1 and c<=4 and not used[key(c,row)] then found={c,row}; break end
        end
        if found then break end
        for _,dr in ipairs({-radius,radius}) do
          local r=row+dr
          if r>=1 and r<=7 and not used[key(col,r)] then found={col,r}; break end
        end
        if found then break end
      end
      if found then col,row=found[1],found[2] end
    end
    used[key(col,row)]=true
    placed[n.id]={col=col,row=row,node=n}
  end
  return placed
end


-- Returns a list of { node=, tree=, row=, col= } for the given client nodes.
function FLT.TalentFallbackLayout(groups, all, class, configID)
  local cols=splitIntoThree(groups, all, class, configID)
  local placed={}
  for ti,nodes in ipairs(cols) do
    local grid=assignGrid(nodes)
    for _,n in ipairs(nodes) do
      local gp=grid[n.id] or {col=1,row=1}
      placed[#placed+1]={node=n,tree=ti,row=gp.row,col=gp.col}
    end
  end
  return placed
end
