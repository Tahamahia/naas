// Bunny.net Stream integration
// Uses env variables from Cloudflare Workers binding

export interface BunnyVideo {
  guid: string;
  title: string;
  status: number;
  length: number;
  thumbnailUrl: string;
  framerate: number;
}

export async function uploadVideo(file: File, apiKey: string, libraryId: string): Promise<BunnyVideo> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(
    `https://video.bunnycdn.com/library/${libraryId}/videos`,
    {
      method: 'POST',
      headers: { 'AccessKey': apiKey },
      body: formData,
    }
  );

  if (!res.ok) throw new Error('Bunny upload failed');
  return res.json();
}

export async function fetchVideo(videoId: string, apiKey: string, libraryId: string): Promise<BunnyVideo> {
  const res = await fetch(
    `https://video.bunnycdn.com/library/${libraryId}/videos/${videoId}`,
    { headers: { 'AccessKey': apiKey } }
  );

  if (!res.ok) throw new Error('Bunny fetch failed');
  return res.json();
}

export async function deleteVideo(videoId: string, apiKey: string, libraryId: string): Promise<void> {
  const res = await fetch(
    `https://video.bunnycdn.com/library/${libraryId}/videos/${videoId}`,
    {
      method: 'DELETE',
      headers: { 'AccessKey': apiKey },
    }
  );

  if (!res.ok) throw new Error('Bunny delete failed');
}
